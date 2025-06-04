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
CREATE PROCEDURE delete_node(IN node_id INT)
BEGIN
    -- Delete the node and all its descendants recursively
    WITH RECURSIVE descendants AS (
        SELECT id FROM adjacency_nodes WHERE id = node_id
        UNION ALL
        SELECT a.id FROM adjacency_nodes a
        INNER JOIN descendants d ON a.parent_id = d.id
    )
    DELETE FROM adjacency_nodes WHERE id IN (SELECT id FROM descendants);
END$$
---- [Move Node] ----
CREATE PROCEDURE move_node(
    IN node_id INT,
    IN new_parent INT
)
BEGIN
    -- Prevent moving node under itself or descendants (to avoid cycles)
    IF node_id = new_parent THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot set parent to itself';
    END IF;

    -- Check if new_parent is a descendant of node_id (which would create a cycle)
    WITH RECURSIVE descendants AS (
        SELECT id FROM adjacency_nodes WHERE id = node_id
        UNION ALL
        SELECT a.id FROM adjacency_nodes a
        INNER JOIN descendants d ON a.parent_id = d.id
    )
    SELECT COUNT(*) INTO @cnt FROM descendants WHERE id = new_parent;

    IF @cnt > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot move node under its own descendant';
    END IF;

    UPDATE adjacency_nodes SET parent_id = new_parent WHERE id = node_id;
END$$
---- [reading all descendants of a given tree node (direct and indirect)] ----
CREATE PROCEDURE get_all_descendants(IN node_id INT)
BEGIN
    WITH RECURSIVE descendants AS (
        SELECT id, name, parent_id FROM adjacency_nodes WHERE id = node_id
        UNION ALL
        SELECT a.id, a.name, a.parent_id FROM adjacency_nodes a
        INNER JOIN descendants d ON a.parent_id = d.id
    )
    SELECT * FROM descendants WHERE id != node_id;
END$$
---- [reading descendants at the selected level] ----
CREATE PROCEDURE get_descendants_at_level(IN node_id INT, IN level INT)
BEGIN
    WITH RECURSIVE descendants AS (
        SELECT id, name, parent_id, 0 AS depth FROM adjacency_nodes WHERE id = node_id
        UNION ALL
        SELECT a.id, a.name, a.parent_id, d.depth + 1 FROM adjacency_nodes a
        INNER JOIN descendants d ON a.parent_id = d.id
    )
    SELECT id, name, parent_id FROM descendants WHERE depth = level;
END$$
---- [reading the direct ancestor of a given node] ----
CREATE PROCEDURE get_direct_ancestor(IN node_id INT)
BEGIN
    SELECT parent.*
    FROM adjacency_nodes child
    JOIN adjacency_nodes parent ON child.parent_id = parent.id
    WHERE child.id = node_id;
END$$
---- [reading all ancestors of a given node] ----
CREATE PROCEDURE get_all_ancestors(IN node_id INT)
BEGIN
    WITH RECURSIVE ancestors AS (
        SELECT id, name, parent_id FROM adjacency_nodes WHERE id = node_id
        UNION ALL
        SELECT a.id, a.name, a.parent_id FROM adjacency_nodes a
        INNER JOIN ancestors anc ON anc.parent_id = a.id
    )
    SELECT * FROM ancestors WHERE id != node_id;
END$$
---- [reading the ancestors of a given node at a selected level] ----
CREATE PROCEDURE get_ancestors_at_level(IN node_id INT, IN level INT)
BEGIN
    WITH RECURSIVE ancestors AS (
        SELECT id, name, parent_id, 0 AS depth FROM adjacency_nodes WHERE id = node_id
        UNION ALL
        SELECT a.id, a.name, a.parent_id, depth + 1 FROM adjacency_nodes a
        JOIN ancestors anc ON anc.parent_id = a.id
    )
    SELECT id, name, parent_id FROM ancestors WHERE depth = level;
END$$
---- [reading "siblings" (other nodes at the same level)] ----
CREATE PROCEDURE get_siblings(IN node_id INT)
BEGIN
    DECLARE parent_id INT;
    SELECT parent_id INTO parent_id FROM adjacency_nodes WHERE id = node_id;
    SELECT * FROM adjacency_nodes WHERE parent_id = parent_id AND id != node_id;
END$$
---- [verify that the tree does not contain cycles] ----
CREATE PROCEDURE verify_no_cycles()
BEGIN
    -- For each node, check if it appears in its own ancestors, which indicates a cycle
    DECLARE cycle_found INT DEFAULT 0;

    WITH RECURSIVE ancestors AS (
        SELECT id, parent_id, id AS root_id FROM adjacency_nodes
        UNION ALL
        SELECT a.id, a.parent_id, ancestors.root_id FROM adjacency_nodes a
        JOIN ancestors ON a.id = ancestors.parent_id
    )
    SELECT COUNT(*) INTO cycle_found
    FROM ancestors
    WHERE id = parent_id;

    IF cycle_found > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cycle detected in the tree';
    END IF;
END$$
---- [verify that the tree is consistent] ----
CREATE PROCEDURE verify_no_cycles()
BEGIN
    -- For each node, check if the node appears in its own ancestor chain
    DECLARE cycle_count INT DEFAULT 0;

    WITH RECURSIVE ancestors AS (
        SELECT id, parent_id, id AS start_id FROM adjacency_nodes
        UNION ALL
        SELECT a.id, a.parent_id, ancestors.start_id FROM adjacency_nodes a
        JOIN ancestors ON a.id = ancestors.parent_id
    )
    SELECT COUNT(*) INTO cycle_count
    FROM ancestors
    WHERE id = start_id AND id != parent_id;

    IF cycle_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cycle detected in the tree';
    END IF;
END$$