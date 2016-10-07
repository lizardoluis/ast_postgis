CREATE TYPE _ast_topologicalrelationship AS ENUM
(
    'contains',
    'containsproperly',
    'covers',
    'coveredby',
    'crosses',
    'disjoint',
    'intersects',
    'overlaps',
    'touches',
    'within'
);
