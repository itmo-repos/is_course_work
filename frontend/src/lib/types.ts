export type User = {
  id: number;
  type: 'EMPLOYEE' | 'DEPOSITOR';
  email: string;
  roles: string[];
};

export type Sample = {
  accessionCode: string;
  latinName: string;
  localName: string;
  originCountry: string;
  collectionYear: number | null;
  seedQuantity: number | null;
  depositorName: string;
};

export type Country = {
  code: string;
  name: string;
};
