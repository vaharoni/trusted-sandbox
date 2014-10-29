# Trusted Sandbox

Run untrusted ruby code in a contained sandbox, using Docker. This gem was inspired by [Harry Marr's work][1].

## Instant gratification

Trusted Sandbox makes it simple to execute Ruby classes that `eval` untrusted code in a resource-controlled docker container.
```ruby
# lib/my_function.rb

class MyFunction
  attr_reader :input

  def initialize(user_code, input)
    @user_code = user_code
    @input = input
  end

  def run
    eval @user_code
  end
end

# somewhere_else.rb

untrusted_code = "input[:number] ** 2"

# The following will run inside a Docker container
output = TrustedSandbox.run! MyFunction, untrusted_code, {number: 10}
# => 100
```

Classes you want to run in a container need to respond to #initialize and #run. Trusted Sandbox serializes the
arguments sent to #initialize, loads the container, instantiates an object, and calls #run.

## Installing

### Step 1
Add this to your gemfile:

  gem 'trusted_sandbox'

or run this:

  gem install trusted_sandbox

### Step 2
Install Docker. Refer to the Docker documentation to see how to install Docker on your environment.

### Step 3 (optional)
Run:

  $ rake trusted_sandbox:install_image

which by default installs the 1.9.3 Ruby image on the server. You can override it by following the guidelines in
"Configuring rake tasks" section, or using `IMAGE_NAME` environment variable:

  $ IMAGE_NAME="my_user/my_image_repo:my_image_version" rake trusted_sandbox:install_image

If you don't run this rake command, Docker will automatically install the image the first time you use Trusted
Sandbox - a process that may take a few minutes.

### Step 4
If you'd like to limit swap memory or set user quotas you'll have to install additional programs on your server.
Follow the instructions in the relevant sections of the configuration guide.

## Configuring Trusted Sandbox

### Docker access
```ruby
TrustedSandbox.config do |c|
  c.docker_url = 'https://192.168.59.103:2376'                                  # Default is ENV['DOCKER_HOST']
  c.docker_cert_path = File.expand_path('~/.boot2docker/certs/boot2docker-vm')  # Default is ENV['DOCKER_CERT_PATH']
  c.docker_image_repo = 'my_docker_repo'                                        # Default is 'vaharoni/trusted_sandbox'
  c.docker_image_tag = 'v2'                                                     # Default is 'latest'

  # Optional authentication
  c.docker_login user: 'my_user', password: 'password', email: 'user@email.com'
end
```

Trusted Sandbox uses the `docker-api` gem to communicate with docker. All the parameters above are used to setup
the global `Docker` class. For finer control of its configuration, you can set `c.docker_options = {...}`, which
will override any configuration and passed through to `Docker.options`.

### Limiting resources
```ruby
TrustedSandbox.config do |c|
  # CPU
  c.cpu_shares = 1                            # Relative units. Default is 1

  # Memory
  c.memory_limit = 50 * 1024 * 1024           # In bytes. Default is 50MB
  c.enable_swap_limit = true                  # Default is false. See swap memory section.
  c.memory_swap_limit = 50 * 1024 * 1024      # In bytes. Default is 50MB, though enable_swap_limit is false by default.

  # Execution
  c.execution_timeout = 10                    # In seconds. Default is 15 seconds
  c.network_access = false                    # Default is false

  # Quotas
  c.enable_quotas = true                      # Default is false. See user quotas section.
  c.host_code_root_path = '/my/path'          # Parent folder to hold mounted directories to where code is copied.
                                              # Default is './tmp/code_dirs'
end
```
Note that controlling memory swap limits and user quotas requires additional steps as outlined below.

### Limiting swap memory

In order to limit swap memory, you'll need to set up your host server to allow that.
The following should work for Debian / Ubuntu:

  $ sudoedit /etc/default/grub

  # Edit the following line
  GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"

  $ sudo update-grub

Reboot the server, and you should be set. Read more about it [here][2].
Remember to run `c.enable_swap_limit = true` in the configuration block.

### Limiting user quotas

In order to control quotas we follow the technique suggested by [Harry Marr][3]. It makes use of the fact that
UIDs (user IDs) and GIDs (Group IDs) are shared between the host and its containers. When a container starts, we
run the untrusted code under an unprivileged user whose UID has a quota enforced by the host.

In order to enable quotas do the following on the server:

  $ sudo apt-get install quota

And follow [these instructions][4], which are also brought here for completeness:

  $ sudo vim /etc/fstab

  # Add ,usrquota in the end of column no. 4 so it looks something like:
  # LABEL=cloudimg-rootfs   /        ext4   defaults,discard,usrquota       0 0

  $ mount -o remount

Then reboot the server, and run the following:

  $ QUOTA_KB=10000 rake trusted_sandbox:set_quotas

This sets the ~10MB quota on all UIDs that are in the range defined by `c.pool_size` and `c.pool_min_uid`. If you
change these configuration parameters you must rerun the rake command. Refer to "Configuring rake tasks" section to
make the rake task aware of your changes.

Remember to run `c.enable_quotas = true` in the configuration block.

Note: There is no way to assign different quotas to different users.

### Limiting network

The only option available is to turn on and off network access using `c.enable_network`. Finer control of network
access is currently not supported. If you need this feature please share your use case in the Issues section.

### Configuring rake tasks

Trusted Sandbox comes equipped with some useful rake tasks.

Download and install an image on the host machine:

  $ IMAGE_NAME="user/repo:version" rake trusted_sandbox:install_image   # Default IMAGE_NAME is "vaharoni/trusted_sandbox:1.9.3.v1"

Building your custom image:

  $ TARGET=/path/to/dir/ rake trusted_sandbox:generate_image_files      # Default TARGET is "server_images"

  $ SOURCE=server_images/1.9.3 IMAGE_NAME="my_image:v1" rake trusted_sandbox:build_image


Setting user quotas:

  $ QUOTA_KB=10000 rake trusted_sandbox:set_quotas

You can configure the `TrustedSandbox` class for all of these rake tasks by defining a `trusted_sandbox:setup` task in
your Rakefile:

```ruby
task 'trusted_sandbox:setup' do
  TrustedSandbox.config do |c|
    c.docker_url = 'https://192.168.59.103:2376'
    c.docker_login user: 'my_user', password: 'password', email: 'user@email.com'
    # ...
  end
end
```

## Using Trusted Sandbox

### Class and argument serialization

The class you send to a container can be as elaborate as you want, providing a context of execution for the user code.
When you call `run` or `run!` with a class constant, the file where that class is defined is copied to the
/home/sandbox/src folder inside the container. Any arguments needed to instantiate an object from that class are
serialized. When the container starts, it deserializes these arguments, invokes the `new` method with them, and runs
`run` on the instantiated object. The output of that method is then serialized back to the host.

A less trivial example:
```ruby
# my_function.rb

# Assuming this gem is in the Gemfile of both the container and the host.
# If you want to access a gem that is only available to the container, put the require directive inside
# #initialize or #run.
require 'hashie/mash'

class MyFunction

  attr_reader :a, :b
  def initialize(first_user_func, second_user_func, a, b)
    @first_user_func = first_user_func
    @second_user_func = second_user_func
    @a = a
    @b = b
  end

  def run
    # Will have access to #a and #b through attr_reader
    result1 = eval(@first_user_func)

    result2 = Context.new(result1).run(@second_user_func)
    [result1, result2]
  end

  class Context
    attr_reader :x
    def initialize(x)
      @x = x
    end

    def run(code)
      eval code
    end
  end
end

# Somewhere else
a, b = TrustedSandbox.run! MyFunction, "a + b", "x ** 2", 2, 5
# => 49
```
Because serialization occurs through Marshalling, you should use primitive Ruby classes for your inputs as much as
possible. You can prepare a docker image with additional gems, as explained in the "Using custom docker images"
section. At this time copying arbitrary files to containers as means as accessing custom classes is not supported.
If you need this feature, please share your use case in the Issues section.

### Running containers

There are two ways to run a container. Use `run!` to retrieve output from the container. If the user code raised
an exception, it will be raised by `run!`.

```ruby
output = TrustedSandbox.run! MyFunction, "input ** 2", 10
# => 100
```
Use `run` to retrieve a response object. The response object provides additional useful information about the
container execution.

Here is an error scenario:
```ruby
response = TrustedSandbox.run MyFunction, "raise 'error!'", 10

response.status
# => "error"

response.valid?
# => false

response.output
# => nil

response.output!
# => TrustedSandbox::UserCodeError: error!

response.error
# => #<RuntimeError: error!>

response.error.backtrace
# => /home/sandbox/src/my_function.rb:14:in `eval'
# => /home/sandbox/src/my_function.rb:14:in `eval'
# => /home/sandbox/src/my_function.rb:14:in `run'

# Can be useful if MyFunction prints to stdout
puts response.stdout

# Can be useful for environment related errors
puts response.stderr
```
```ruby
Here is a successful scenario:

response = TrustedSandbox.run MyFunction, "input ** 2", 10

response.status
# => "success"

response.valid?
# => true

response.output
# => 100

response.output!
# => 100

response.error
# => nil
```
### Overriding specific invocations

To override a configuration parameter for a specific invocation, use `with_options`:
```ruby
TrustedSandbox.with_options(cpu_shares: 2) do |s|
  s.run! MyFunction, untrusted_code, input
end
```
You should not override user quota related parameters, as they must be prepared on the host in advance of execution.

## Using custom docker images

Trusted Sandbox comes with two ready-to-use images:

Ruby 1.9.3 image:
```ruby
# Lightweight image, fast to build, based on `apt-get install ruby`.
c.docker_image_repo = 'vaharoni/trusted_sandbox'
c.docker_image_tag = '1.9.3.v1'
```

Ruby 2.1.2 image:

```ruby
# Builds Ruby from source, slower to build.
c.docker_image_repo = 'vaharoni/trusted_sandbox'
c.docker_image_tag = '2.1.2.v1'
```

Both images have ActiveSupport gem installed.

To use images from your Docker Hub account:

```ruby
c.login user: 'your_user', password: 'password', email: 'my@email.com'
c.docker_image_repo = 'your_user/my_repo_name'
c.docker_image_tag = 'your_image_tag'
```

To customize one of the provided images, run the following. It will copy the image definitions to your current
directory under `server_images`.

  $ rake trusted_sandbox:generate_image_files

Alternatively, you can copy the definitions to a different target directory relative to the current directory:

  $ TARGET=config/server_images rake trusted_sandbox:generate_image_files

After modifying the files to your satisfaction, you can either push it to your Docker Hub account, or build directly
on the server:

  $ SOURCE=server_images/1.9.3 IMAGE_NAME="my_image:v1" rake trusted_sandbox:build_image

## Troubleshooting

If you encounter issues, try troubleshooting them by accessing your container's bash. Run the following in the
configuration block:

```ruby
c.keep_code_folders = true
```
This will keep your code folders from getting deleted when containers stop running. This allows you to do the
following from your command line (adjust to your environment):

  $ docker run -it -v /home/MyUser/my_app/tmp/code_dirs/20000:/home/sandbox/src --entrypoint="/bin/bash" my_image:my_tag

## License
Licensed under the [MIT license](http://opensource.org/licenses/MIT).

[1]: http://hmarr.com/2013/oct/16/codecube-runnable-gists/
[2]: https://www.digitalocean.com/community/articles/how-to-enable-user-quotas
[3]: http://hmarr.com/2013/oct/16/codecube-runnable-gists/
[4]: https://www.digitalocean.com/community/tutorials/how-to-enable-user-quotas
