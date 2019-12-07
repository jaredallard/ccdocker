
[![License (MIT)](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](http://opensource.org/licenses/MIT)
[![Language (Lua)](https://img.shields.io/badge/powered_by-Lua-blue.svg?style=flat-square)](https://lua.org)
[![Platform (ComputerCraft)](https://img.shields.io/badge/platform-ComputerCraft-blue.svg?style=flat-square)](http://www.computercraft.info/)


# ccdocker

A Docker-like application for ComputerCraft!

## What does it do?

It emulates operating systems and programs in shipable containers/images.

## How does it do it?

The magic of `setfenv` and `getfenv`.

## Setup

Download a github release!

-- or --

Pull from source.
Then, in the folder run

```
pastebin get uHRTm9hp Howl
```

Now run `Howl combine`, and check `build`!

**OPTIONAL**: Run `Howl minify` to minify the release!

**Even better**: Run `Howl combine minify` to do them both!

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

 * Jared Allard &lt;jaredallard(at)outlook.com&gt;

## License

MIT
