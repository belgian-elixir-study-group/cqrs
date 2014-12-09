defmodule UniqueID do
  def generate do
    Kernel.make_ref()
  end
end

defmodule EventBus do

  @name {:local, __MODULE__}

  def start_link do
    :gen_event.start_link(@name)
  end

  def init(_) do
    :ok
  end

  def add_listener(listener) do
    :gen_event.add_handler(@name, listener, [])
  end

  def listeners do
    :gen_event.which_handlers(@name)
  end

  def broadcast(uuid, event) do
    :gen_event.notify(@name, {event, uuid})
  end

end

defmodule EventStore do

  def start_link do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def store(uuid, event) do
    Agent.update(__MODULE__, fn (events) ->
      [{uuid, event} | events]
    end)
  end

  def fetch(uuid) do
    Agent.get(__MODULE__, fn (events) ->
      events
      |> Enum.filter(fn {event_uuid, event} -> event_uuid == uuid end)
      |> Enum.map(fn {_, event} -> event end)
      |> Enum.reverse
    end)
  end

end

defmodule DomainRepository do

  def trigger(entity, event) do
    entity = apply_event(entity, event)
    store_event(entity.uuid, event)
    broadcast_event(entity.uuid, event)
    entity
  end

  def apply_event(entity, event) do
    entity.__struct__.apply(entity, event)
  end

  defp store_event(uuid, event) do
    EventStore.store(uuid, event)
  end

  defp broadcast_event(uuid, event) do
    EventBus.broadcast(uuid, event)
  end

  def get(mod, uuid) do
    EventStore.fetch(uuid)
    |> Enum.reduce(mod.new, &apply_event(&2, &1))
  end

end

defmodule PotionStore do
  defmodule ShoppingCart do

    defstruct uuid: nil, items: []

    alias __MODULE__, as: Cart

    def new do
      %Cart{}
    end

    def create(uuid) do
      event = {:cart_created, %{uuid: uuid}}
      cart = %Cart{}
      DomainRepository.trigger(cart, event)
    end

    def add_item(cart, item) do
      event = {:item_added, %{item: item}}
      DomainRepository.trigger(cart, event)
    end

    def get(uuid) do
      DomainRepository.get(__MODULE__, uuid)
    end

    #

    def apply(cart, {:cart_created, %{uuid: uuid}}) do
      %{cart | uuid: uuid}
    end

    def apply(cart, {:item_added, %{item: item}}) do
      %{cart | items: [item|cart.items]}
    end

  end
end

defmodule EventDebugger do
  use GenEvent

  def init(_opts) do
    {:ok, 0}
  end

  def handle_event({event, uuid}, counter) do
    counter = counter + 1
    IO.puts "Event ##{counter} #{inspect event}, UUID: #{inspect uuid}"
    {:ok, counter}
  end

end

EventBus.start_link
EventStore.start_link


IO.inspect EventBus.listeners

#EventBus.add_listener(ItemCounter)
EventBus.add_listener(EventDebugger)

cart_uuid = UniqueID.generate

cart =
  PotionStore.ShoppingCart.create(cart_uuid)
  |> PotionStore.ShoppingCart.add_item("Artline 100N")
  |> PotionStore.ShoppingCart.add_item("Coke classic")
  |> PotionStore.ShoppingCart.add_item("Coke zero")
IO.inspect cart

IO.puts "====================="

cart = PotionStore.ShoppingCart.get(cart_uuid)
IO.inspect cart