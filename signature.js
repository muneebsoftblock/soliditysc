const { time } = require("@openzeppelin/test-helpers")
const Web3 = require("web3")

const web3 = new Web3("https://rpc-mumbai.matic.today")

const privateKey = "dfbeda793c0d2bebee953029221fcc5a7c2cfa38403a27ad0fe0cf399cba9fc4"

const userAddress = ""
const totalSupply = ""
const timestamp = Date.now().toString()

const message = "12" + "100" + timestamp

const prefixedMessage = web3.utils.sha3("\x19Ethereum Signed Message:\n32" + message)

const signature = web3.eth.accounts.sign(prefixedMessage, privateKey)

console.log(signature)
console.log(timestamp)
console.log(message)

const recoveredAddress = web3.eth.accounts.recover(prefixedMessage, signature.signature)

console.log("Recovered Address! ", recoveredAddress)
