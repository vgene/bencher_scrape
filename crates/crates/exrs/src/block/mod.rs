//! Handle uncompressed pixel byte blocks. Includes compression and decompression,
//! and some functions that completely read an image into blocks.

pub mod lines;
pub mod samples;

use crate::compression::{ByteVec, Compression};
use crate::math::*;
use crate::error::{Result, Error, usize_to_i32, UnitResult};
use crate::meta::{MetaData, Header, Blocks, TileIndices};
use crate::chunk::{Chunk, Block, TileBlock, ScanLineBlock, TileCoordinates};
use crate::meta::attributes::LineOrder;
use rayon::prelude::ParallelBridge;
use rayon::iter::ParallelIterator;
use smallvec::alloc::collections::BTreeMap;
use std::convert::TryFrom;
use crate::io::{Tracking, PeekRead};
use std::io::{Seek, Read};
use crate::image::{ReadOptions, OnReadProgress};




/// Specifies where a block of pixel data should be placed in the actual image.
/// This is a globally unique identifier which
/// includes the layer, level index, and pixel location.
#[derive(Clone, Copy, Eq, Hash, PartialEq, Debug)]
pub struct BlockIndex {

    /// Index of the layer.
    pub layer: usize,

    /// Pixel position of the bottom left corner of the block.
    pub pixel_position: Vec2<usize>,

    /// Pixel size of the block.
    pub pixel_size: Vec2<usize>,

    /// Index of the mip or rip level in the image.
    pub level: Vec2<usize>,
}

/// Contains a block of pixel data and where that data should be placed in the actual image.
#[derive(Clone, Eq, PartialEq, Debug)]
pub struct UncompressedBlock {

    /// Location of the data inside the image.
    pub index: BlockIndex,

    /// Uncompressed pixel values of the whole block.
    /// One or more scan lines may be stored together as a scan line block.
    /// This byte vector contains all pixel rows, one after another.
    /// For each line in the tile, for each channel, the row values are contiguous.
    pub data: ByteVec,
}




/// Reads and decompresses all chunks of a file sequentially without seeking.
/// Will not skip any parts of the file. Does not buffer the reader, you should always pass a `BufReader`.
#[inline]
#[must_use]
pub fn read_all_blocks_from_buffered<T>(
    read: impl Read + Send, // FIXME does not actually need to be send, only for parallel writing
    new: impl Fn(&[Header]) -> Result<T>,
    mut insert: impl FnMut(&mut T, &[Header], UncompressedBlock) -> UnitResult,
    options: ReadOptions<impl OnReadProgress>,
) -> Result<T>
{
    let (meta_data, chunk_count, mut read_chunk) = self::read_all_compressed_chunks_from_buffered(read, options.max_pixel_bytes)?;
    let meta_data_ref = &meta_data;

    let read_chunks = std::iter::from_fn(move || read_chunk(meta_data_ref));
    let mut result = new(meta_data.headers.as_slice())?;

    for_decompressed_blocks_in_chunks(
        read_chunks, &meta_data,
        |meta, block| insert(&mut result, meta, block),
        chunk_count, options
    )?;

    Ok(result)
}



/// Reads ad decompresses all desired chunks of a file sequentially, possibly seeking.
/// Will skip any parts of the file that do not match the specified filter condition.
/// Will never seek if the filter condition matches all chunks.
/// Does not buffer the reader, you should always pass a `BufReader`.
#[inline]
#[must_use]
pub fn read_filtered_blocks_from_buffered<T>(
    read: impl Read + Seek + Send, // FIXME does not always need be Send
    new: impl FnOnce(&[Header]) -> Result<T>, // TODO put these into a trait?
    filter: impl Fn(&T, &Header, &TileIndices) -> bool,
    mut insert: impl FnMut(&mut T, &[Header], UncompressedBlock) -> UnitResult,
    options: ReadOptions<impl OnReadProgress>,
) -> Result<T>
{
    let (meta_data, mut value, chunk_count, mut read_chunk) = {
        self::read_filtered_chunks_from_buffered(read, new, filter, options.max_pixel_bytes)?
    };

    for_decompressed_blocks_in_chunks(
        std::iter::from_fn(|| read_chunk(&meta_data)), &meta_data,
        |meta, line| insert(&mut value, meta, line),
        chunk_count, options
    )?;

    Ok(value)
}

/// Iterates through all lines of all supplied chunks.
/// Decompresses the chunks either in parallel or sequentially.
#[inline]
#[must_use]
fn for_decompressed_blocks_in_chunks(
    chunks: impl Send + Iterator<Item = Result<Chunk>>,
    meta_data: &MetaData,
    mut for_each: impl FnMut(&[Header], UncompressedBlock) -> UnitResult,
    total_chunk_count: usize,
    mut options: ReadOptions<impl OnReadProgress>,
) -> UnitResult
{
    // TODO bit-vec keep check that all pixels have been read?
    let has_compression = meta_data.headers.iter() // do not use parallel stuff for uncompressed images
        .any(|header| header.compression != Compression::Uncompressed);

    let mut processed_chunk_count = 0;

    if options.parallel_decompression && has_compression {
        let (sender, receiver) = std::sync::mpsc::channel();

        chunks.par_bridge()
            .map(|chunk| UncompressedBlock::decompress_chunk(chunk?, &meta_data))
            .try_for_each_with(sender, |sender, result| {
                result.map(|block: UncompressedBlock| sender.send(block).expect("threading error"))
            })?;

        for decompressed in receiver {
            options.on_progress.on_read_progressed(processed_chunk_count as f32 / total_chunk_count as f32)?;
            processed_chunk_count += 1;

            for_each(meta_data.headers.as_slice(), decompressed)?; // allows returning `Error::Abort`
        }

        Ok(())
    }
    else {
        for chunk in chunks {
            options.on_progress.on_read_progressed(processed_chunk_count as f32 / total_chunk_count as f32)?;
            processed_chunk_count += 1;

            let decompressed = UncompressedBlock::decompress_chunk(chunk?, &meta_data)?;
            for_each(meta_data.headers.as_slice(), decompressed)?; // allows returning `Error::Abort`
        }

        Ok(())
    }
}

/// Read all chunks without seeking.
/// Returns the meta data, number of chunks, and a compressed chunk reader.
/// Does not buffer the reader, you should always pass a `BufReader`.
#[inline]
#[must_use]
pub fn read_all_compressed_chunks_from_buffered<'m>(
    read: impl Read + Send, // FIXME does not actually need to be send, only for parallel writing
    max_pixel_bytes: Option<usize>,
) -> Result<(MetaData, usize, impl FnMut(&'m MetaData) -> Option<Result<Chunk>>)>
{
    let mut read = PeekRead::new(read);
    let meta_data = MetaData::read_from_buffered_peekable(&mut read, max_pixel_bytes)?;
    let mut remaining_chunk_count = usize::try_from(MetaData::skip_offset_tables(&mut read, &meta_data.headers)?)
        .expect("too large chunk count for this machine");

    Ok((meta_data, remaining_chunk_count, move |meta_data| {
        if remaining_chunk_count > 0 {
            remaining_chunk_count -= 1;
            Some(Chunk::read(&mut read, meta_data))
        }
        else {
            None
        }
    }))
}


/// Read all desired chunks, possibly seeking. Skips all chunks that do not match the filter.
/// Returns the compressed chunks. Does not buffer the reader, you should always pass a `BufReader`.
// TODO this must be tested more
#[inline]
#[must_use]
pub fn read_filtered_chunks_from_buffered<'m, T>(
    read: impl Read + Seek + Send, // FIXME does not always need be Send
    new: impl FnOnce(&[Header]) -> Result<T>,
    filter: impl Fn(&T, &Header, &TileIndices) -> bool,
    max_pixel_bytes: Option<usize>,
) -> Result<(MetaData, T, usize, impl FnMut(&'m MetaData) -> Option<Result<Chunk>>)>
{
    let skip_read = Tracking::new(read);
    let mut read = PeekRead::new(skip_read);
    let meta_data = MetaData::read_from_buffered_peekable(&mut read, max_pixel_bytes)?;

    let value = new(meta_data.headers.as_slice())?;

    let offset_tables = MetaData::read_offset_tables(&mut read, &meta_data.headers)?;

    let mut offsets = Vec::with_capacity(meta_data.headers.len() * 32);
    for (header_index, header) in meta_data.headers.iter().enumerate() { // offset tables are stored same order as headers
        for (block_index, block) in header.blocks_increasing_y_order().enumerate() { // in increasing_y order
            if filter(&value, header, &block) {
                offsets.push(offset_tables[header_index][block_index]) // safe indexing from `enumerate()`
            }
        };
    }

    offsets.sort(); // enables reading continuously if possible (is probably already sorted)
    let mut offsets = offsets.into_iter();
    let block_count = offsets.len();

    Ok((meta_data, value, block_count, move |meta_data| {
        offsets.next().map(|offset|{
            read.skip_to(usize::try_from(offset).expect("too large chunk position for this machine"))?; // no-op for seek at current position, uses skip_bytes for small amounts
            Chunk::read(&mut read, meta_data)
        })
    }))
}



/// Iterate over all uncompressed blocks of an image.
/// The image contents are collected by the `get_line` function parameter.
/// Returns blocks in `LineOrder::Increasing`, unless the line order is requested to be decreasing.
#[inline]
#[must_use]
pub fn uncompressed_image_blocks_ordered<'l>(
    meta_data: &'l MetaData,
    get_block: &'l (impl 'l + Sync + (Fn(&[Header], BlockIndex) -> Vec<u8>)) // TODO reduce sync requirements, at least if parrallel is false
) -> impl 'l + Iterator<Item = Result<(usize, UncompressedBlock)>> + Send // TODO reduce sync requirements, at least if parrallel is false
{
    meta_data.headers.iter().enumerate()
        .flat_map(move |(layer_index, header)|{
            header.enumerate_ordered_blocks().map(move |(chunk_index, tile)|{
                let data_indices = header.get_absolute_block_indices(tile.location).expect("tile coordinate bug");

                let block_indices = BlockIndex {
                    layer: layer_index, level: tile.location.level_index,
                    pixel_position: data_indices.position.to_usize("data indices start").expect("data index bug"),
                    pixel_size: data_indices.size,
                };

                let block_bytes = get_block(meta_data.headers.as_slice(), block_indices);

                // byte length is validated in block::compress_to_chunk
                Ok((chunk_index, UncompressedBlock {
                    index: block_indices,
                    data: block_bytes
                }))
            })
        })
}



/// Compress all chunks in the image described by `meta_data` and `get_line`.
/// Calls `write_chunk` for each compressed chunk, while respecting the `line_order` of the image.
///
/// Attention: Currently, using multi-core compression with `LineOrder::Increasing` or `LineOrder::Decreasing` in any header
/// will allocate large amounts of memory while writing the file. Use unspecified line order for lower memory usage.
#[inline]
#[must_use]
pub fn for_compressed_blocks_in_image(
    meta_data: &MetaData, get_tile: impl Sync + Fn(&[Header], BlockIndex) -> Vec<u8>,
    parallel: bool, mut write_chunk: impl FnMut(usize, Chunk) -> UnitResult
) -> UnitResult
{
    let blocks = uncompressed_image_blocks_ordered(meta_data, &get_tile);

    let parallel = parallel && meta_data.headers.iter() // do not use parallel stuff for uncompressed images
        .any(|header| header.compression != Compression::Uncompressed);

    let requires_sorting = meta_data.headers.iter()
        .any(|header| header.line_order != LineOrder::Unspecified);


    if parallel {
        let (sender, receiver) = std::sync::mpsc::channel();

        blocks.par_bridge()
            .map(|result| Ok({
                let (chunk_index, block) = result?;
                let block = block.compress_to_chunk(meta_data)?;
                (chunk_index, block)
            }))
            .try_for_each_with(sender, |sender, result: Result<(usize, Chunk)>| {
                result.map(|block| sender.send(block).expect("threading error"))
            })?;

        if !requires_sorting {
            // FIXME does the original openexr library support unspecified line orders that have mixed up headers???
            //       Or must the header order always be contiguous without overlaps?
            for (chunk_index, compressed_chunk) in receiver {
                write_chunk(chunk_index, compressed_chunk)?;
            }
        }

        // write parallel chunks with sorting
        else {

            // the block indices, in the order which must be apparent in the file
            let mut expected_id_order = meta_data.headers.iter().enumerate()
                .flat_map(|(layer, header)| header.enumerate_ordered_blocks().map(move |(chunk, _)| (layer, chunk)));

            // the next id, pulled from expected_id_order: the next block that must be written
            let mut next_id = expected_id_order.next();

            // set of blocks that have been compressed but not written yet
            let mut pending_blocks = BTreeMap::new();

            // receive the compressed blocks
            for (chunk_index, compressed_chunk) in receiver {
                pending_blocks.insert((compressed_chunk.layer_index, chunk_index), compressed_chunk);

                // write all pending blocks that are immediate successors
                while let Some(pending_chunk) = next_id.as_ref().and_then(|id| pending_blocks.remove(id)) {
                    let pending_chunk_index = next_id.unwrap().1; // must be safe in this branch
                    write_chunk(pending_chunk_index, pending_chunk)?;
                    next_id = expected_id_order.next();
                }
            }

            assert!(expected_id_order.next().is_none(), "expected more blocks bug");
            assert_eq!(pending_blocks.len(), 0, "pending blocks left after processing bug");
        }
    }

    else {
        for result in blocks {
            let (chunk_index, uncompressed_block) = result?; // enable `Error::Abort`
            let chunk = uncompressed_block.compress_to_chunk(meta_data)?;
            write_chunk(chunk_index, chunk)?;
        }
    }

    Ok(())
}


impl UncompressedBlock {

    /// Decompress the possibly compressed chunk and returns an `UncompressedBlock`.
    // for uncompressed data, the ByteVec in the chunk is moved all the way
    #[inline]
    #[must_use]
    pub fn decompress_chunk(chunk: Chunk, meta_data: &MetaData) -> Result<Self> {
        let header: &Header = meta_data.headers.get(chunk.layer_index)
            .ok_or(Error::invalid("chunk layer index"))?;

        let tile_data_indices = header.get_block_data_indices(&chunk.block)?;
        let absolute_indices = header.get_absolute_block_indices(tile_data_indices)?;

        absolute_indices.validate(Some(header.data_size))?;

        match chunk.block {
            Block::Tile(TileBlock { compressed_pixels, .. }) |
            Block::ScanLine(ScanLineBlock { compressed_pixels, .. }) => Ok(UncompressedBlock {
                data: header.compression.decompress_image_section(header, compressed_pixels, absolute_indices)?,
                index: BlockIndex {
                    layer: chunk.layer_index,
                    pixel_position: absolute_indices.position.to_usize("data indices start")?,
                    level: tile_data_indices.level_index,
                    pixel_size: absolute_indices.size,
                }
            }),

            _ => return Err(Error::unsupported("deep data not supported yet"))
        }
    }

    /// Consume this block by compressing it, returning a `Chunk`.
    // for uncompressed data, the ByteVec in the chunk is moved all the way
    #[inline]
    #[must_use]
    pub fn compress_to_chunk(self, meta_data: &MetaData) -> Result<Chunk> {
        let UncompressedBlock { data, index } = self;

        let header: &Header = meta_data.headers.get(index.layer)
            .expect("block layer index bug");

        let expected_byte_size = header.channels.bytes_per_pixel * self.index.pixel_size.area(); // TODO sampling??
        if expected_byte_size != data.len() {
            panic!("get_line byte size should be {} but was {}", expected_byte_size, data.len());
        }

        let compressed_data = header.compression.compress_image_section(data)?;

        Ok(Chunk {
            layer_index: index.layer,
            block : match header.blocks {
                Blocks::ScanLines => Block::ScanLine(ScanLineBlock {
                    compressed_pixels: compressed_data,

                    // FIXME this calculation should not be made here but elsewhere instead (in meta::header?)
                    y_coordinate: usize_to_i32(index.pixel_position.y()) + header.own_attributes.data_position.y(),
                }),

                Blocks::Tiles(tiles) => Block::Tile(TileBlock {
                    compressed_pixels: compressed_data,
                    coordinates: TileCoordinates {
                        level_index: index.level,

                        // FIXME this calculation should not be made here but elsewhere instead (in meta::header?)
                        tile_index: index.pixel_position / tiles.tile_size,
                    },

                }),
            }
        })
    }
}