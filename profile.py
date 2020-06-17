#!/usr/bin/python

"""Profile for running these benchmarks across multiple CloudLab machine.

Instructions:
"""

import geni.portal as portal
import geni.rspec as pg

pc = portal.Context()
rspec = pg.Request()

# Create 1 "RawPC" node (more later)
n = 1

for i in range( n ):
    # Create "RawPC" node
    node = pg.RawPC("node" + str(i))
    # Request hardware
    node.hardware_type = "c220g5"
    # Create interfaces for each node
    iface = node.addInterface("if" + str(i))
    # Specify URL to disk image
    #node.disk_image = ""
    # Install and Execute specific script
    #node.addService(pg.Install(url="", path=""))
    #node.addService(pg.Execute(shell="bash", command=""))
    # Add to RSpec
    rspec.addResource(node)

# Print RSpec to enclosing page
pc.printRequestRSpec(rspec)
