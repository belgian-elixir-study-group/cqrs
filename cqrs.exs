defmodule UniqueID do
  def generate do
    Kernel.make_ref()
  end
end

defmodule DomainRepository do

  def trigger(entity, event) do
    store_event(event)
    apply_event(entity, event)
  end

  def apply_event(entity, event) do
    entity.__struct__.apply(entity, event)
  end

  defp store_event(event) do
  end

end

defmodule PotionStore do
  defmodule ShoppingCart do

    defstruct uuid: nil, items: []

    alias __MODULE__, as: Cart

    def create() do
      event = {:cart_created, %{uuid: UniqueID.generate}}
      cart = %Cart{}
      DomainRepository.trigger(cart, event)
    end

    def add_item(cart, item) do
      event = {:item_added, %{item: item}}
      DomainRepository.trigger(cart, event)
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


cart =
  PotionStore.ShoppingCart.create()
  |> PotionStore.ShoppingCart.add_item("Artline 100N")
  |> PotionStore.ShoppingCart.add_item("Coke classic")
  |> PotionStore.ShoppingCart.add_item("Coke zero")
IO.inspect cart

