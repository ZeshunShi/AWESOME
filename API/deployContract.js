const fs = require('fs');
const solc = require('solc');
const Web3 = require('web3');
// const contractFile = require('./compile');

// Get Path and Load Contract
// const source = fs.readFileSync('../contracts/subContracts/placeBids.sol', 'utf8');
const source = fs.readFileSync('../contracts/SLA.sol', 'utf8');

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


// Initialization
const web3 = new Web3('http://localhost:7545');
const address = '0xa1eF58670368eCCB27EdC6609dea0fEFC5884f09';
const privKey ='5b3208286264f409e1873e3709d3138acf47f6cc733e74a6b47a040b50472fd8';

const abi = contractFile.abi;
const bytecode = contractFile.evm.bytecode.object;
const constructorArgs = ["5","10","10","10","10","20"]

const CloudAuction = new web3.eth.Contract(abi);
const CloudAuctionTx = CloudAuction.deploy({data: bytecode,arguments: constructorArgs,});
// Deploy contract
const deploy = async () => {
      console.log('Attempting to deploy from account:', address);
      const createTransaction = await web3.eth.accounts.signTransaction({from: address, data: CloudAuctionTx.encodeABI(), gas: '53278380', gasPrice: '10000000000'},privKey);
      const createReceipt = await web3.eth.sendSignedTransaction(createTransaction.rawTransaction);
      console.log('Contract deployed at address', createReceipt.contractAddress);
      };
deploy()