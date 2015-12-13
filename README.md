# Smith — A simple Multi Agent System (MAS) based on AMQP and protobuf.

# Smith2
Smith is an Multi Agent system that allows agents to be easily controlled by
sending messages to an agency that does your bidding. It also provides an ACL
framework so agents can very easily communicate. All communication is done
over an AMQP message passing layer.

## Getting started

### Configuration

First of you need a config file: `.smithrc`. This can be in the current working directory, `$HOME`,
`/etc/smithrc` or `/etc/smith/smithrc`. These files will be searched for in that order. If a valid
config can't be found the agency will fail. See the examples directory for an example.

A number of config options can also be set using environment variables:

* SMITH_PID_DIRECTORY
* SMITH_CACHE_DIRECTORY
* SMITH_ACL_DIRECTORIES
* SMITH_AGENT_DIRECTORIES
* SMITH_BROKER_URI

The pid and cache directories must exist beforehand.

### The agency

The agency is used to control the agents: start, stop, list running agents,
etc. Once started it simply listens for messages telling it what to do.
To start the agency you simple type:

```
agency
```

It will log messages as specified in `.smithrc`. I suggest for all development
work you set `logging.appender = stderr`.


### Agents

So now you got a running agency you need an agent to run. Agents are small
chunks of code that generally have a single purpose (much in the same way a
class should). They generally listen on a queue and respond to each ACL (An
ACL is a protobuf encoded message. See below for more details) it receives. 

An example of a simple agent is:

```ruby
class SimpleAgent < Smith::Agent

  def run
    receiver('my.queue').subscribe(method(:worker))
  end

  def worker(payload, receiver)
    logger.debug { payload.inspect }
  end
end
```

The run method is run once when the agent is started by the agency. You can add
anything in here. In fact it server a similar purpose to the `initialize`
method in a normal class. In this `run` method a receiver is being setup which
creates a queue called `my.queue` and attaches a method to it (`worker`).

The method `worker` (this can be anything and you would almost certainly not
something that means something to your agent and not `worker`!) gets called for
every ACL received on that queue. This method simply logs the ACL.

There are two parameters to the method: `payload` and `receiver` — they can be
called anything you like but I recommend you name like that. The `payload` is
the ACL and `receiver` is a metadata object that allows you to perform more
sophisticated operations such as replying to an ACL.

In a nutshell that is about it! Of course the above is (almost) the simplest
agent you can possibly write (to make it simpler the `subscribe` method could
call a block directly but you probably shouldn't do that).

### Agent Communication Language (ACL)

ACLs are how agents communicate with each other and use Google's Protocol
Buffers. This gives a typesafe way for agents to communicate.

A simple ACL is:

```
package ACL;
message Test {
  optional string content = 1;
}
```

You should read the [Protocol Buffers Developer
Guide](https://developers.google.com/protocol-buffers/docs/overview) to get a
better understanding. Note smith2 uses version 2, it is unlikely to ever use
version 3.

### Smithctl

`smithctl` is used to control the agency and provide some useful functions
(such as publishing ACLs to queues)

To display a full list of commands run

```
smithctl commands [--long]
```

The `--long` option will give a brief overview of the command's function.

### Doing something useful

That's all very well but how do I actually start an agent!

So assuming the agency is running you run the following commands will get you
going:

To start an agent:

```lang=zsh
smithctl start SimpleAgent
```

To publish a message to a queue:

```lang=zsh
smithctl push --type Smith::ACL::Test --message= '{"content":"foo"}' my.queue
```

To list all running agents:

```lang=sh
smithctl list --long
```

To stop an agent by name (if you have multiple instances of the agent running
this command will stop them all):

```lang=sh
smithctl stop --name SimpleAgent
```

To stop an agent using it's UUID

```lang=sh
smithctl stop <UUID>
```

To list all agents available:

```lang=sh
smithctl agents
```


## History

Smith2 is a complete rewrite of Smith. Smith worked; after a fashion,
but there were lots of problems that made it hard to work with. So this
rewrite aims to fix these issues. Properly.

While Smith2 in many ways works better than Smith there are still things
that aren't implemented, not to mention all the new stuff that I want
to put in.
