# input = { number: 10 }
#
# untrusted_code = <<-CODE
#   input[:number] ** 2
# CODE
#
# # This code is run in a restricted docker container
# TrustedSandbox.run! App::UserFunction, untrusted_code, input
#
# TrustedSandbox.with_options(memory_limit: 100 * 1024 * 1024) do |ts|
#   output = ts.run App::UserFunction, untrusted_code, input
# end