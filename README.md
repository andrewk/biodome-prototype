BIODOME
=======

Environment Monitoring, Logging, Scheduling and Compensation using Arduino
---------------------------------------------------------------------------

**Released under the MIT license**


This library is primarily intended for automation of a greenhouse or similar agricultural uses. I develeoped it to start seedlings indoors over winter, grow miniature capsicums (sweet peppers) year-round (I'm trying to breed a miniature heart-shapped capsicum... with little success) and to provide optimal conditions for my bonsai collection.

The primary example provided with this library (examples/Biodome/Biodome.pde) is the configuration I use for capsicums. I have included it specifically because it attempts to provide complete control of the environment rather than a more simple compensation system. Reading the Biodome.h/.cpp files will provide little of obvious use, I suggest instead you look at the examples/Biodome/Biodome.pde file for a complete implementation of an automated and monitored environment using the classes defined in this library. 

While I would have preferred to encapsulate the workings of the automation and monitoring in an Object Oriented design, the limited bytecode footprint of the Arduino made it a higher priority to keep the codebase as small as possible while still being easy to modify.
