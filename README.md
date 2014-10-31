# Trusted Sandbox

Run untrusted ruby code in a contained sandbox, using Docker. This gem was inspired by [Harry Marr's work][1].

## Instant gratification

Trusted Sandbox makes it simple to execute Ruby classes that `eval` untrusted code in a resource-controlled docker
container.

The simplest way to get started is run "inline" code within a container:

```ruby
require 'trusted_sandbox'

untrusted_code = "input[:number] ** 2"

# The following will run inside a Docker container
output = TrustedSandbox.run_code! untrusted_code, input: {number: 10}
# => 100
```

`run_code!` receives user code and an arguments hash. Any key in the arguments hash is available when the user code
executes.

In addition, you can send any class to execute within a Docker container. All you need is to have the class respond to
`initialize` and `run`. Trusted Sandbox loads the container, copies the class file to the container, serializes the
arguments sent to `initialize`, instantiates an object, calls `run`, and serializes its return value back to the host.

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
```
```ruby
# somewhere_else.rb
require 'trusted_sandbox'
require 'lib/my_function'

untrusted_code = "input[:number] ** 2"

# The following will run inside a Docker container
output = TrustedSandbox.run! MyFunction, untrusted_code, {number: 10}
# => 100
```

## Installing

### Step 1
Add this line to your application's Gemfile:
```
gem 'trusted-sandbox'
```

And then execute:
```
$ bundle
```
Or install it yourself as:
```
$ gem install trusted-sandbox
```

### Step 2
Install Docker, Server version >= 1.2.0. Note that at the time of writing some distro package management systems have
an earlier version. Refer to the Docker documentation to see how to install the latest Docker on your environment.

Note that on a Linux server the docker daemon runs as root, and the root user owns the socket used to connect to the
daemon. In order to avoid the need to run your application with sudo privileges, add the application user to the
`docker` group (keep `${USER}` for the connected user or change to suit your needs):
```
$ sudo gpasswd -a ${USER} docker
$ sudo service docker.io restart
```
then reconnect to your shell session and try the following (without sudo):
```
$ docker images
```
If it works, then you are all set.

You can read more about this issue [here][5].

### Step 3
Run the following command which will copy the `trusted_sandbox.yml` file into your current directory, or
`config` directory if it exists:
```
$ trusted_sandbox install
```

Then follow the configuration instructions in this guide. Once you're done configuring, test your installation by
running:
```
$ trusted_sandbox test
```

### Step 4
Install the image. This step is optional, as Docker automatically installs images when you first run them. However,
since it takes a few minutes we suggest you do this in advance.
```
$ docker run --rm vaharoni/trusted_sandbox:2.1.2.v1
```
If you see the message "you must provide a uid", then you are set.

Consider restarting the docker service if you receive an error that looks like this:
`Error response from daemon: Cannot start container 9f3bd8d72f0704980cedacc068261c38e280e7314916245550a6d48431ea8f11:
fork/exec /var/lib/docker/init/dockerinit-1.0.1: cannot allocate memory`

```
$ sudo service docker.io restart
```
and then try again.

### Step 5

If you'd like to limit swap memory or set user quotas you'll have to install additional programs on your server.
Follow the instructions in the relevant sections of the configuration guide.

## Configuring Trusted Sandbox

Let's go over the sections of the YAML configuration file you created in step 3 above.
The top key of the YAML file is an environment string that can be set by `TRUSTED_SANDBOX_ENV` or `RAILS_ENV`
environment variables.

### Docker connection

Trusted Sandbox uses the `docker-api` gem to communicate with docker. `docker-api`'s defaults work quite well for a
Linux host, and you should be good by omitting `docker_url` and `docker_cert_path` all together.

```ruby
# If omitted ENV['DOCKER_HOST'] is used. If it is not set, docker-api defaults are used.
docker_url: https://192.168.59.103:2376

# If omitted ENV['DOCKER_CERT_PATH'] is used. If it is not set, docker-api defaults are used.
docker_cert_path: ~/.boot2docker/certs/boot2docker-vm
```
If you need finer control of `docker-api` configuration, you can add a `docker_options` hash entry to the
YAML file which will override any configuration and passed through to `Docker.options`.

In addition, these docker-related configuration parameters can be used:
```ruby
docker_image_name: vaharoni/trusted_sandbox:2.1.2.v1

# Optional authentication
docker_login:
  user: my_user
  password: my_password
  email: email@email.com
```


### Limiting resources
CPU:
```ruby
  cpu_shares:        1              # In relative units
```
Memory:
```ruby
  memory_limit:      52_428_800     # In bytes
  enable_swap_limit: false
  memory_swap_limit: 52_428_800     # In bytes. Relevant only if enable_swap_limit is true.
```
Execution
```ruby
  execution_timeout: 15             # In seconds
  network_access:    false
```
Quotas
```ruby
  enable_quotas:     false
```
Settings for UID-pool used for assigning user quotas. Always used, even if quota functionality is disabled.
It's very unlikely you'll need to touch these:
```ruby
  pool_size:         5000
  pool_min_uid:      20000
  pool_timeout:      3
  pool_retries:      5
  pool_delay:        0.5
```
Note that controlling memory swap limits and user quotas requires additional steps as outlined below.

### Execution parameters

```ruby
# A temporary folder under which sub folders are created and mounted to containers.
# The code and args exchange between the host and containers is done via these sub folders.
host_code_root_path: tmp/code_dirs

# When set to true, the temporary sub folders will not be erased. This allows you to login
# to the container to troubleshoot issues as explained in the "Troubleshooting" section.
keep_code_folders: false

# When set to true, containers will not be erased after they finish running. This allows you
# to troubleshoot issues by viewing container parameters and logs as explained in the
# "Troubleshooting" section.
keep_containers: false

# A folder used by the UID-pool to handle locks.
host_uid_pool_lock_path: tmp/uid_pool_lock
```

### Limiting swap memory

In order to limit swap memory, you'll need to set up your host server to allow that.
The following should work for Debian / Ubuntu.

First, run:
```
$ sudoedit /etc/default/grub
```
and edit the following line:
```
GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"
```
Then run:
```
$ sudo update-grub
```
Reboot the server, and you should be set. Read more about it [here][2].
Remember to set `enable_swap_limit: true` in the YAML file.

### Limiting user quotas

Note: due to permission setting scheme, limiting user quota does not work on OS or Windows.

In order to control quotas we follow the technique suggested by [Harry Marr][3]. It makes use of the fact that
UIDs (user IDs) and GIDs (Group IDs) are shared between the host and its containers. When a container starts, we
run the untrusted code under an unprivileged user whose UID has a quota enforced by the host.

In order to enable quotas do the following on the server:
```
$ sudo apt-get install quota
```
And follow [these instructions][4] as well as [this resource][6], which we bring here for completeness. Note that these
may vary for your distro.

```
$ sudo vim /etc/fstab
```
Add `,usrquota` in the end of column no. 4 so it looks something like:
```
LABEL=cloudimg-rootfs   /        ext4   defaults,discard,usrquota       0 0
```
Then do:
```
$ sudo touch /aquota.user
$ sudo chmod 600 /aquota.*
$ sudo mount -o remount /
```
and **reboot the server**. Then do:
```
$ sudo quotacheck -avum
$ sudo quotaon -avu
```
You should see something like this:
```
/dev/disk/by-uuid/d36a9e2f-dae9-477f-8aea-29f1bdd1c04e [/]: user quotas turned on
```

To actually set the quotas, run the following (quota is in KB):
```
$ sudo trusted_sandbox set_quotas 10000
```
This sets ~10MB quota on all UIDs that are in the range defined by `pool_size` and `pool_min_uid` parameters. If you
change these configuration parameters you must rerun the `set_quotas` command.

Remember to set `enable_quotas: true` in the YAML file.

To get a quota report, do:
```
$ sudo repquota -a
```

### Limiting network

The only option available is to turn on and off network access using `enable_network`. Finer control of network
access is currently not supported. If you need this feature please open an issue and share your use case.

## Using Trusted Sandbox

### Class and argument serialization

The class you send to a container can be as elaborate as you want, providing a context of execution for the user code.
When you call `run` or `run!` with a class constant, the file where that class is defined is copied to the
`/home/sandbox/src` folder inside the container. Any arguments needed to instantiate an object from that class are
serialized. When the container starts, it deserializes these arguments, invokes the `new` method with them, and runs
`run` on the instantiated object. The output of that method is then serialized back to the host.

A less trivial example:
```ruby
# my_function.rb

# Example for requiring a gem, assuming it is in the Gemfile of both the container and the
# host. If you want to access a gem that is only available to the container, put the require
#  directive inside `initialize` or `run` methods.
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
```
```ruby
# Somewhere else
require 'trusted_sandbox'
require 'my_function'
a, b = TrustedSandbox.run! MyFunction, "a + b", "x ** 2", 2, 5
# => 49
```
Because serialization occurs through Marshalling, you should use primitive Ruby classes for your inputs as much as
possible. You can prepare a docker image with additional gems and custom Ruby classes, as explained in the
"Using custom docker images" section.

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
Here is a success scenario:
```ruby
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

Trusted Sandbox comes with one ready-to-use image that includes Ruby 2.1.2. It is hosted on Docker Hub under
`vaharoni/trusted_sandbox:2.1.2.v1`.

To use a different image from your Docker Hub account simply change the configuration parameters in the YAML file.

To customize the provided images, run the following. It will copy the image definition to your current directory under
`trusted_sandbox_images/2.1.2`.
```
$ trusted_sandbox generate_image
```

After modifying the files to your satisfaction, you can either push it to your Docker Hub account, or build directly
on the server. Assuming you kept the image under trusted_sandbox_images/2.1.2:
```
$ docker build -t "your_user/your_image_name:your_image_version" trusted_sandbox_images/2.1.2
```

## Troubleshooting

If you encounter issues, try troubleshooting them by accessing your container's bash. Make the following change in the
YAML file:

```ruby
keep_code_folders: true
```
This will keep your code folders from getting deleted when containers stop running. This allows you to do the
following from your command line (adjust to your environment):
```
$ docker run -it -v /home/MyUser/my_app/tmp/code_dirs/20000:/home/sandbox/src --entrypoint="/bin/bash" my_user/my_image:my_tag -s
```
Note that this will also take out that specific UID from the UID-pool so that future runs don't remount the same folder.
To release that UID back to the pool, either reset that specific UID:
```
$ trusted_sandbox reset_uid_pool 20000
```
or reset all UIDs (make sure no other containers are running):
```
$ trusted_sandbox reset_uid_pool
```

To avoid containers from being deleted after they finish running, set:
```ruby
keep_containers: true
```
This will allow you to view containers by running `docker ps -a` and then check out container logs
`docker logs CONTAINER_ID` or container parameters `docker inspect CONTAINER_ID`.

You will need to delete containers yourself by running `docker rm CONTAINER_ID`. To delete all of your containers do:
```
$ docker ps -aq | xargs docker rm
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License
Licensed under the [MIT license](http://opensource.org/licenses/MIT).

[1]: http://hmarr.com/2013/oct/16/codecube-runnable-gists/
[2]: https://www.digitalocean.com/community/tutorials/how-to-enable-user-and-group-quotas
[3]: http://hmarr.com/2013/oct/16/codecube-runnable-gists/
[4]: https://www.digitalocean.com/community/tutorials/how-to-enable-user-quotas
[5]: http://askubuntu.com/questions/477551/how-can-i-use-docker-without-sudo
[6]: http://www.howtoforge.com/how-to-set-up-journaled-quota-on-debian-lenny