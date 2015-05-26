# ccdocker

A Docker-like application for ComputerCraft!

## What does it do?

It emulates operating systems and programs in shipable containers.

## How does it do it?

The magic of setfenv and getfenv.

## Setup

First, download the git sources into /docker

i.e git clone <url> docker

Then you may access the ccdocker script, as well as the docker library. (soon to be name ccdocker.)

## USAGE

```
USAGE: ccdocker [OPTIONS] COMMAND [arg...]

A self contained runtime for computercraft code.

Commands:
 pull     Pull an image from a ccDocker repository
 push     Push an image to a ccDocker repository
 build    Build an image.
 run      Run a command in a new container.
 register Register on a ccDocker repository.
 version  Show the ccdocker version.
 help     Show this help
```

## Developers

 * Jared Allard &lt;rainbowdashdc&amp;pony.so&gt;

## License

MIT
