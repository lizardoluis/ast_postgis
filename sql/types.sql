CREATE TYPE _ast_spatialrelationship AS ENUM
(
    'contains',
    'containsproperly',
    'covers',
    'coveredby',
    'crosses',
    'disjoint',
    'distant',
    'intersects',
    'near',
    'overlaps',
    'touches',
    'within'
);
