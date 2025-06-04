------------------------------ [ Definition ] ------------------------------
DROP TABLE IF EXISTS path_enum_nodes;

CREATE TABLE path_enum_nodes (
    id INT PRIMARY KEY,
    name TEXT,
    path TEXT
);

------------------------------ [ Example Data ] ------------------------------
INSERT INTO path_enum_nodes (id, name, path)
VALUES (1, 'A', '/1/');

INSERT INTO path_enum_nodes (name, path)
VALUES ('B', '/1/2/'),
       ('C', '/1/3/');

INSERT INTO path_enum_nodes (name, path)
VALUES ('D', '/1/2/4/'),
       ('E', '/1/2/5/');

------------------------------ [Functions] ------------------------------
---- [Add Node] ----
---- [Delete Node] ----
---- [Move Node] ----
---- [reading all descendants of a given tree node (direct and indirect)] ----
---- [reading descendants at the selected level] ----
---- [reading the direct ancestor of a given node] ----
---- [reading all ancestors of a given node] ----
---- [reading the ancestors of a given node at a selected level] ----
---- [reading "siblings" (other nodes at the same level)] ----
---- [verify that the tree does not contain cycles] ----
---- [verify that the tree is consistent] ----