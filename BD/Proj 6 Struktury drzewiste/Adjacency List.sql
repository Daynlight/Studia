-- ---------------------------- [ Definition ] ------------------------------
DROP TABLE IF EXISTS adjacency_nodes;
CREATE TABLE adjacency_nodes (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    parent_id INT,
    FOREIGN KEY (parent_id) REFERENCES adjacency_nodes(id) ON DELETE CASCADE
);
/*
-- ---------------------------- [ Example Data ] ------------------------------
INSERT INTO adjacency_nodes (id, name, parent_id) VALUES
(1, 'A', NULL),
(2, 'B', 1),
(3, 'C', 1),
(4, 'D', 2),
(5, 'E', 2);
*/
-- ---------------------------- [Functions] ------------------------------
DELIMITER $$

-- -- [Add Node] ----
DROP PROCEDURE IF EXISTS add_node;
CREATE PROCEDURE add_node(
    IN node_name VARCHAR(50),
    IN parent INT
)
BEGIN
    DECLARE new_id INT;

    -- Get the next available ID
    SELECT IFNULL(MAX(id), 0) + 1 INTO new_id
    FROM adjacency_nodes;

    -- Insert the new node
    INSERT INTO adjacency_nodes (id, name, parent_id)
    VALUES (new_id, node_name, parent);
END$$

-- -- [Delete Node] ----
DROP PROCEDURE IF EXISTS delete_node;
CREATE PROCEDURE delete_node(IN node_id INT)
BEGIN
    DELETE FROM adjacency_nodes WHERE id = node_id;
END$$

-- -- [Move Node] ----
DROP PROCEDURE IF EXISTS move_node;
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

-- -- [reading all descendants of a given tree node (direct and indirect)] ----
DROP PROCEDURE IF EXISTS get_all_descendants;
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

-- -- [reading descendants at the selected level] ----
DROP PROCEDURE IF EXISTS get_descendants_at_level;
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

-- -- [reading the direct ancestor of a given node] ----
DROP PROCEDURE IF EXISTS get_direct_ancestor;
CREATE PROCEDURE get_direct_ancestor(IN node_id INT)
BEGIN
    SELECT parent.*
    FROM adjacency_nodes child
    JOIN adjacency_nodes parent ON child.parent_id = parent.id
    WHERE child.id = node_id;
END$$

-- -- [reading all ancestors of a given node] ----
DROP PROCEDURE IF EXISTS get_all_ancestors;
CREATE PROCEDURE get_all_ancestors(IN node_id INT)
BEGIN
    WITH RECURSIVE ancestors AS (
        SELECT id, name, parent_id FROM adjacency_nodes WHERE id = (
            SELECT parent_id FROM adjacency_nodes WHERE id = node_id
        )
        UNION ALL
        SELECT a.id, a.name, a.parent_id FROM adjacency_nodes a
        INNER JOIN ancestors anc ON a.id = anc.parent_id
    )
    SELECT * FROM ancestors;
END;

-- -- [reading the ancestors of a given node at a selected level] ----
DROP PROCEDURE IF EXISTS get_ancestors_at_level;
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

-- -- [reading "siblings" (other nodes at the same level)] ----
DROP PROCEDURE IF EXISTS get_siblings;
CREATE PROCEDURE get_siblings(IN node_id INT)
BEGIN
    DECLARE parent_id INT;
    SELECT parent_id INTO parent_id FROM adjacency_nodes WHERE id = node_id;
    SELECT * FROM adjacency_nodes WHERE parent_id = parent_id AND id != node_id;
END$$

-- -- [verify that the tree does not contain cycles] ----
DROP PROCEDURE IF EXISTS verify_no_cycles;
CREATE PROCEDURE verify_no_cycles()
BEGIN
    DECLARE cycle_count INT DEFAULT 0;

    WITH RECURSIVE path AS (
        SELECT id AS start_id, parent_id, id AS current_id
        FROM adjacency_nodes
        WHERE parent_id IS NOT NULL

        UNION ALL

        SELECT p.start_id, a.parent_id, a.id AS current_id
        FROM path p
        JOIN adjacency_nodes a ON p.parent_id = a.id
    )
    SELECT COUNT(*) INTO cycle_count
    FROM path
    WHERE start_id = current_id;

    IF cycle_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cycle detected in the tree';
    END IF;
END;

DELIMITER ;


-- ---------------------------- [ Test Suite for adjacency_nodes ] ------------------------------
-- [Setup: Initial Tree]
-- A (1)
-- ├── B (2)
-- │   ├── D (4)
-- │   └── E (5)
-- └── C (3)

INSERT INTO adjacency_nodes (id, name, parent_id) VALUES
(1, 'A', NULL),
(2, 'B', 1),
(3, 'C', 1),
(4, 'D', 2),
(5, 'E', 2);

-- [Test: Add Node F under B]
CALL add_node('F', 2);
SELECT * FROM adjacency_nodes ORDER BY id;

-- [Test: Get all descendants of A]
CALL get_all_descendants(1);

-- [Test: Get descendants of B at level 1]
CALL get_descendants_at_level(2, 1);

-- [Test: Get direct ancestor of D]
CALL get_direct_ancestor(4);

-- [Test: Get all ancestors of D]
CALL get_all_ancestors(4);

-- [Test: Get ancestors of D at level 1]
CALL get_ancestors_at_level(4, 1);

-- [Test: Get siblings of D]
CALL get_siblings(4);

-- [Test: Verify no cycles]
CALL verify_no_cycles();

-- [Test: Move D under C]
CALL move_node(4, 3);
SELECT * FROM adjacency_nodes ORDER BY id;

-- [Test: Try to move C under its own descendant D (should fail)]
-- Expected: error
-- CALL move_node(3, 4);

-- [Test: Delete B (and its descendants)]
SELECT * FROM adjacency_nodes ORDER BY id;
CALL delete_node(2);
SELECT * FROM adjacency_nodes ORDER BY id;