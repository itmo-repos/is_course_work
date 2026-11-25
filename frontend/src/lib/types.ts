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

export type DepositorStatus =
  | 'NEW_REQUEST' | 'AWAITING_CONTRACT' | 'VERIFICATION'
  | 'CONTRACT_REJECTED' | 'ACTIVE' | 'REJECTED';

export type DepositorApplication = {
  id: number;
  legalName: string;
  countryName: string;
  registrationNumber: string;
  legalAddress: string;
  contactPerson: string;
  contactEmail: string;
  contactPhone: string | null;
  status: DepositorStatus;
  rejectionReason: string | null;
  contract: { number: string } | null;
};

export type Species = {
  id: number;
  latinName: string;
  localName: string;
};

export type SamplePassport = {
  speciesId: number;
  originCountryCode: string;
  collectionYear: number;
  seedQuantity: number;
  note: string;
};

export type BatchData = {
  desiredShipmentDate: string;
  boxes: { samples: SamplePassport[] }[];
};

export type Batch = {
  id: number;
  number: string;
  status: 'FORMED' | 'CONFIRMED' | 'REJECTED' | 'IN_TRANSIT' | 'ARRIVED' | 'INSPECTION' | 'PLACED' | 'PARTIALLY_PLACED' | 'WRITTEN_OFF';
  desiredShipmentDate: string;
  boxCount: number;
  rejectionReason: string | null;
  boxes: {
    id: number;
    seqNo: number;
    barcode: string | null;
    samples: (Omit<SamplePassport, 'note'> & {
      id: number;
      accessionCode: string;
      latinName: string;
      note: string | null;
    })[];
  }[];
};
