const Web3 = require("web3")

const web3 = new Web3("https://rpc-mumbai.matic.today")

const privateKey = "dfbeda793c0d2bebee953029221fcc5a7c2cfa38403a27ad0fe0cf399cba9fc4"

const userAddress = ""
const totalSupply = ""
const timestamp = Date.now().toString();


const message = "ahmed" + timestamp;

const signature = web3.eth.accounts.sign(message, privateKey)

console.log(signature)

const recoveredAddress = web3.eth.accounts.recover(message, signature.signature)

console.log("Recovered Address! ", recoveredAddress)
