module App
  class UserFunction

    attr_reader :input

    def initialize(user_code, input)
      @user_code = user_code

      # This will be accessible by the user code
      @input = input
    end

    def run
      eval @user_code
    end

  end
end