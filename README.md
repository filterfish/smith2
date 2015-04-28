# @title Smith - A simple Multi Agent System based on AMQP and protobuf.
# @author Richard Heycock

# Smith2
Smith is an Multi Agent system that allows agents to be easily controlled by
sending messages to an agency that does your bidding. It also provides an ACL
framework so agents can very easily communicate. All communication is done
over an AMQP message passing layer.

## Getting started

### Configuration

First of you need a config file: `.smithrc`. This can be in the current working directory, `$HOME`,
`/etc/smithrc` or `/etc/smith/smithrc`. See the examples directory for an example.

A number of config options can also be set using environment variables:

* SMITH_PID_DIRECTORY
* SMITH_CACHE_DIRECTORY
* SMITH_ACL_DIRECTORIES
* SMITH_AGENT_DIRECTORIES

The pid and cache directories must exist beforehand.

### The agency

The agency is used to control the agents: start, stop, list runnning agents,
etc. Once started it simply listens for messages telling it what to do.
To start the agent you simple type:

```
agency
```

It will log messages as specified in the `.smithrc`. I suggest for all
development work you set it `stderr`.


### Smithctl

`smithctl` is used to control the agency and provide some useful functions
(such as publishing ACLs to queues)

To display a full list of commands run

```
smithctl commands [--long]
```

The `--long` option will give a brief overview of the command's function.


## History

Smith2 is a complete rewrite of Smith. Smith worked, after a fashion,
but there were lots of problems that made it hard to work with. So this
rewrite aims to fix these issues. Properly.

While Smith2 in many ways works better than Smith there are still things
that aren't implemented, not to mention all the new stuff that I want
to put in.

