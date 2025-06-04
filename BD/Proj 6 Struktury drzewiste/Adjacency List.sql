------------------------------ [ Definition ] ------------------------------
Drop TAble adjacency_nodes;

CREATE TABLE adjacency_nodes (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    parent_id INT,
    FOREIGN KEY (parent_id) REFERENCES adjacency_nodes(id)
);

------------------------------ [ Example Data ] ------------------------------
INSERT INTO adjacency_nodes (id, name, parent_id) VALUES
(1, 'A', NULL),
(2, 'B', 1),
(3, 'C', 1),
(4, 'D', 2),
(5, 'E', 2);

------------------------------ [Functions] ------------------------------
---- [Add Node] ----
CREATE PROCEDURE add_node(
    IN node_name VARCHAR(50),
    IN parent INT
)
BEGIN
    DECLARE new_id INT;
    SELECT IFNULL(MAX(id), 0) + 1 INTO new_id FROM adjacency_nodes;
    INSERT INTO adjacency_nodes (id, name, parent_id)
    VALUES (new_id, node_name, parent);
END$$
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