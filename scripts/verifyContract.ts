const { ethers } = require('hardhat');
import config from "./config";
import { verifyContract } from "./utils/verifyContract";

async function main() {
  const resp = await verifyContract(config.tomb, [])

  console.log('done', resp);
};

main()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
})