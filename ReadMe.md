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


=====================

The contract is well written, and no apparent issues are identified. However, there are a few improvements and things to consider:

User Engagement: You're using totalUsers as a counter for the number of users who have staked tokens. However, once a user unstakes, you decrease the counter. This could lead to an inaccurate count if a user stakes and unstakes multiple times. If you want to track unique users who have ever staked, you should implement a different logic.

Weight Calculation: You calculate stakedDuration and stakedAmount in the getUserRewards function using integer division. This can lead to truncation errors. Consider using a library like OpenZeppelin's SafeMath to perform the division with decimal points, which will give you a more accurate result.

Reward Calculation: The formula to calculate the reward in the getUserRewards function seems a bit complex. I'd suggest adding more detailed comments to describe the logic behind it. This would help others reading your code to understand your intention.

Security: Consider adding additional checks or modifiers to ensure that certain values cannot be set to malicious or undesirable values. For example, you might want to ensure that the set_REWARD_PERIOD and set_TOTAL_REWARD_TOKENS functions cannot be used to set these values to zero.

Code Readability: Some parts of the code, like the getMultiplier function, could be simplified for better readability. For instance, you could use a switch statement or a mapping to replace the series of if/else if statements.

Code Efficiency: The stake function can become quite gas intensive if a user stakes a large number of tokens. Consider the gas costs and if possible, optimize the function.