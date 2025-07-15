# clips_rcsml_agent
A simple [ROS2 CLIPS Executive](https://github.com/carologistics/clips_executive/) based agent for the RoboCup Logistics League (soon to be RoboCup Smart Manufacturing League).
Get started on the RCLL with this project.


## Goals
The idea behind this simple agent is to show a minimally viable RCLL (RCSML) agent that can communicate with the refbox
and the simulation used in the RCLL and use it to produce one order of any complexity with one robot.

It does not support multi-robot setups, planning, producing multiple orders, parallelism, etc., but can be extended to
support these features. It's also a demonstrator of how to build your own CLIPS-agent on top of the ROS2 CX.

## Usage
Once the package is sourced and built (it depends on the ROS2 CLIPS Executive, so this needs to be built and sourced to),
one can simply run

```python
ros2 launch clips_rcsml_agent launch.py
```

to launch the agent. Start the refbox then (with the simulation turned on) and you can see it produce one of the orders.

It is also possible to control the robots of team carologistics using the AgenTask messages (that are used to control the
robots in the simulation). Thus the agent is capable of controlling real robots.

## Future Work
We plan on releasing a tutorial based on this agent and improve its code structure and documentation. We also want to show
how to extend it with other ROS2 CX features to properly control your own robots' hardware.
