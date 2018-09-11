module Consumer
  def self.included(cls)
    cls.class_exec do
      include Log::Dependency

      extend Build
      extend Start

      extend HandlerMacro
      extend IdentifierMacro

      prepend Configure

      initializer :stream_name

      attr_writer :position_update_interval
      def position_update_interval
        @position_update_interval ||= Defaults.position_update_interval
      end

      attr_writer :position_update_counter
      def position_update_counter
        @position_update_counter ||= 0
      end

      attr_accessor :poll_interval_milliseconds

      dependency :dispatch, Dispatch
      dependency :get
      dependency :position_store, PositionStore
      dependency :subscription, Subscription

      virtual :error_raised do |error, message_data|
        raise error
      end
    end
  end

  def call(message_data)
    logger.trace { "Dispatching message (#{LogText.message_data(message_data)})" }

    dispatch.(message_data)

    update_position(message_data.global_position)

    logger.info { "Message dispatched (#{LogText.message_data(message_data)})" }

  rescue => error
    logger.error { "Error raised (Error Class: #{error.class}, Error Message: #{error.message}, #{LogText.message_data(message_data)})" }
    error_raised(error, message_data)
  end

  def identifier
    self.class.identifier
  end

  def start(&probe)
    _, subscription_thread = ::Actor::Start.(subscription)

    actor_address, actor_thread = Actor.start(self, subscription, include: :thread)

    if probe
      subscription_address = subscription.address

      probe.(self, [actor_thread, subscription_thread], [actor_address, subscription_address])
    end

    AsyncInvocation::Incorrect
  end

  def add_handler(handler)
    dispatch.add_handler handler
  end

  def update_position(position)
    logger.trace { "Updating position (Global Position: #{position}, Counter: #{position_update_counter}/#{position_update_interval})" }

    self.position_update_counter += 1

    if position_update_counter >= position_update_interval
      position_store.put(position)

      logger.debug { "Updated position (Global Position: #{position}, Counter: #{position_update_counter}/#{position_update_interval})" }

      self.position_update_counter = 0
    else
      logger.debug { "Interval not reached; position not updated (Global Position: #{position}, Counter: #{position_update_counter}/#{position_update_interval})" }
    end
  end

  def position_update_interval
    @position_update_interval ||= self.class.position_update_interval
  end

  module LogText
    def self.message_data(message_data)
      "Type: #{message_data.type}, Stream: #{message_data.stream_name}, Position: #{message_data.position}, GlobalPosition: #{message_data.global_position}"
    end
  end

  module Configure
    def configure(batch_size: nil, position_store: nil, **)
      logger.trace { "Configuring (Batch Size: #{batch_size})" }

      super if defined?(super)

      starting_position = self.position_store.get

      Subscription.configure(
        self,
        stream_name,
        get,
        position: starting_position,
        poll_interval_milliseconds: poll_interval_milliseconds
      )

      handlers = self.class.handler_registry.get(context: self)

      Dispatch.configure(self, handlers)

      logger.debug { "Done configuring (Batch Size: #{batch_size}, Starting Position: #{starting_position})" }
    end
  end

  module Build
    def build(stream_name, batch_size: nil, position_store: nil, position_update_interval: nil, poll_interval_milliseconds: nil, **arguments)
      instance = new stream_name

      instance.position_update_interval = position_update_interval
      instance.poll_interval_milliseconds = poll_interval_milliseconds

      instance.configure(batch_size: batch_size, position_store: position_store, **arguments)

      instance
    end
  end

  module Start
    def start(stream_name, **arguments, &probe)
      instance = build stream_name, **arguments
      instance.start(&probe)
    end
  end

  module HandlerMacro
    def handler_macro(handler=nil, &block)
      handler ||= block

      handler_registry.register(handler)
    end
    alias_method :handler, :handler_macro

    def handler_registry
      @handler_registry ||= HandlerRegistry.new
    end
  end

  module IdentifierMacro
    attr_writer :identifier

    def identifier_macro(identifier)
      self.identifier = identifier
    end

    def identifier(identifier=nil)
      if identifier.nil?
        @identifier
      else
        identifier_macro(identifier)
      end
    end
  end
end
