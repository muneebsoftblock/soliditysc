make total discount possible and minus it from available price


if minted <= free, price = 0
else fee = (minted - free) * price


minted+=qty
if minted <= free, no fee
else fee = (minted - free) * price

===================================================================================
totDisc = freeItemsCanBuy * itemPrice
price = itemsToBuy * itemPrice
totalPrice = price - totDisc


totalPrice = (itemsToBuy * itemPrice) - (freeItemsCanBuy * itemPrice)
totalPrice = itemPrice (itemsToBuy - freeItemsCanBuy)


totalPrice = itemPrice (itemsToBuy - (numberFreeForAll - numberMinted))


totalPrice =  itemPrice * itemsToBuy - itemPrice * (numberFreeForAll - numberMinted))
totalPrice =  itemPrice * itemsToBuy - itemPrice * numberFreeForAll + itemPrice * numberMinted
totalPrice + itemPrice * numberFreeForAll =  itemPrice * itemsToBuy + itemPrice * numberMinted

===================================================================================
totDisc = freeItemsCanBuy-mintedQty * itemsToBuy
price = itemsToBuy * itemPrice
totalPrice = disc - price