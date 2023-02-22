interface Addresses {
  zeroAddress: string;
  deployer: string;
  vtek: string;
  aceLab: string;
  roar: string;
  gasPrice: string;
  scanner: string;
}

export const contractNameMapper = {
  aceLab: 'AceLab',
};

const config: Addresses = {
  zeroAddress: '0x0000000000000000000000000000000000000000',

  deployer: '0xe9a274F0153c9D24a6C081465e0641ff0bBD0286',
  vtek: '0xeD236c32f695c83Efde232c288701d6f9C23E60E',
  // aceLab: '0xDBC838Ee888407815889d5603bc679A81715F928',
  aceLab: '0xdb52e06a75caab7013a0c3127f7ae80de7be6752',

  roar: '0xFF068652C5D720B2cd4653B0Cc0AF22c4D668a43',
  scanner: 'https://bscscan.com/address/',
  gasPrice: '', // for gasThrottler
};

export default config;
