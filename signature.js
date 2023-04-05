const Web3 = require("web3")
const web3 = new Web3("https://rpc-mumbai.matic.today")
const privateKey =
    "32b37123d4d902a19a23d78adc13dca2f61138a1404fa93a740d0fceb8ecf030"

userAddress = ""
totalSupply = ""

const message = "mytoken!"

// message = userAddress + totalSupply;

const signature = web3.eth.accounts.sign(message, privateKey)

console.log(signature)

// purchaseNft(_howMany = 1, signature.messageHash, _rootNumber = 0, signature.signature);
// { signature object output will be like that
//     message: 'mytoken!',
//     messageHash: '0x9787e39d14dbb28c303a3b270ea35c2c6ade4d8af8ec85ab2d8e548beae58cb9',
//     v: '0x1c',
//     r: '0x54bcfd3e93045cb33b975a6657ef2029ad760ebe630874ccb2e671a963c0bc9f',
//     s: '0x26059be3acb503b6965b354da94d9a38b65976882d93e117a0ea6dd07ed3f0dc',
//     signature: '0x54bcfd3e93045cb33b975a6657ef2029ad760ebe630874ccb2e671a963c0bc9f26059be3acb503b6965b354da94d9a38b65976882d93e117a0ea6dd07ed3f0dc1c'
//   }

// messageHash and signature will be used to recover the owner address than this recovered address will be compared with the caller address to proceed the transaction
