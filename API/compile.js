const fs = require('fs');
const solc = require('solc');

// Get Path and Load Contract
const source = fs.readFileSync('./contracts/CloudAuction.sol', 'utf8');

// Compile Contract
const input = {
   language: 'Solidity',
   sources: {
      'CloudAuction.sol': {
         content: source,
      },
   },
   settings: {
      outputSelection: {
         '*': {
            '*': ['*'],
         },
      },
   },
};
const tempFile = JSON.parse(solc.compile(JSON.stringify(input)));
const contractFile = tempFile.contracts['CloudAuction.sol']['CloudAuction'];
// console.log(contractFile)
// Export Contract Data
module.exports = contractFile;