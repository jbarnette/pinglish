class Pinglish
  class Check
    attr_reader :group
    attr_reader :name
    attr_reader :timeout

    def initialize(name, options = nil, &block)
      options ||= {}
      @group    = options[:group]
      @name     = name
      @timeout  = options[:timeout] || 1
      @block    = block
    end

    # Call this check's behavior, returning the result of the block.

    def call(*args, &block)
      @block.call *args, &block
    end
  end
end
