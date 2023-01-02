const ethers = require('ethers')

const getPK = key => {
  const keyStr = key.split(' ').join('')
  const base64 = Buffer.from(keyStr, 'hex').toString('utf-8')
  return Buffer.from(base64, 'base64').toString('utf-8')
}
const pk1 = getPK('4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35')

const pk2 = getPK('4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34')

// pk1: 0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9
// pk2: 0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48

const wallet1 = new ethers.Wallet(pk1)
const wallet2 = new ethers.Wallet(pk2)
console.log(wallet1.address)
// 0xe92401A4d3af5E446d93D11EEc806b1462b39D15
console.log(wallet2.address)
// 0x81A5D6E50C214044bE44cA0CB057fe119097850c
