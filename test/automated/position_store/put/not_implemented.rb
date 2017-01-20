require_relative '../../automated_init'

context "Position Store" do
  context "Put not implemented" do
    stream = Controls::Stream.example

    position_store = Class.new do
      include Consumer::PositionStore
    end

    position_store = position_store.new stream

    test "Abstract method error not raised" do
      position = Controls::Position::Global.example

      refute proc { position_store.put position } do
        raises_error? Virtual::PureMethodError
      end
    end
  end
end
