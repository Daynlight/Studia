-- ---------------------------- [ Definition ] ------------------------------
DROP TABLE IF EXISTS path_enum_nodes;
CREATE TABLE path_enum_nodes (
    id INT PRIMARY KEY,
    name TEXT,
    parent_id INT NULL,
    path TEXT,
    CONSTRAINT fk_parent FOREIGN KEY (parent_id) REFERENCES path_enum_nodes(id) ON DELETE CASCADE
);

/*
-- ---------------------------- [ Example Data ] ------------------------------
INSERT INTO path_enum_nodes (id, name, path) VALUES
(1, 'A', '1'),
(2, 'B', '1/2'),
(3, 'C', '1/3'),
(4, 'D', '1/2/4'),
(5, 'E', '1/2/5');
*/
-- ---------------------------- [Functions] ------------------------------
DELIMITER $$

-- -- [Add Node] ----
DROP PROCEDURE IF EXISTS add_node;
CREATE PROCEDURE add_node(
    IN node_name TEXT,
    IN parent_id INT
)
BEGIN
    DECLARE new_id INT;
    DECLARE parent_path TEXT;

    -- Get the next available ID
    SELECT IFNULL(MAX(id), 0) + 1 INTO new_id FROM path_enum_nodes;

    -- Get parent path
    SELECT path INTO parent_path FROM path_enum_nodes WHERE id = parent_id;

    -- Insert new node with computed path
    INSERT INTO path_enum_nodes (id, name, path)
    VALUES (new_id, node_name, CONCAT(parent_path, '/', new_id));
END$$

-- -- [Delete Node and Descendants] ----
DROP PROCEDURE IF EXISTS delete_node;
CREATE PROCEDURE delete_node(IN node_id INT)
BEGIN
    -- Check if node exists
    IF NOT EXISTS (SELECT 1 FROM path_enum_nodes WHERE id = node_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Node not found';
    END IF;

    -- Delete the node (will cascade delete descendants)
    DELETE FROM path_enum_nodes WHERE id = node_id;
END$$

-- -- [Move Node] ----
DROP PROCEDURE IF EXISTS move_node;
CREATE PROCEDURE move_node(
    IN node_id INT,
    IN new_parent_id INT
)
BEGIN
    DECLARE old_path TEXT;
    DECLARE new_parent_path TEXT;
    DECLARE new_path TEXT;

    -- Get the current path of the node to move
    SELECT path INTO old_path FROM path_enum_nodes WHERE id = node_id;
    
    -- Get the path of the new parent node
    SELECT path INTO new_parent_path FROM path_enum_nodes WHERE id = new_parent_id;

    -- Prevent moving a node under its own descendant (cycle)
    IF new_parent_path LIKE CONCAT(old_path, '%') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot move node under its own descendant';
    END IF;

    -- Compute new path for the node
    SET new_path = CONCAT(new_parent_path, '/', node_id);

    -- Update the node's path
    UPDATE path_enum_nodes SET path = new_path WHERE id = node_id;

    -- Update all descendants paths safely
    UPDATE path_enum_nodes
    SET path = CONCAT(new_path, SUBSTRING(path, LENGTH(old_path) + 1))
    WHERE id IN (
        SELECT id FROM (
            SELECT id FROM path_enum_nodes WHERE path LIKE CONCAT(old_path, '/%')
        ) AS temp
    );
END$$

-- -- [Get All Descendants] ----
DROP PROCEDURE IF EXISTS get_all_descendants;
CREATE PROCEDURE get_all_descendants(IN node_id INT)
BEGIN
    DECLARE node_path TEXT;
    SELECT path INTO node_path FROM path_enum_nodes WHERE id = node_id;
    SELECT * FROM path_enum_nodes
    WHERE path LIKE CONCAT(node_path, '/%');
END$$

-- -- [Get Descendants at Selected Level] ----
DROP PROCEDURE IF EXISTS get_descendants_at_level;
CREATE PROCEDURE get_descendants_at_level(IN node_id INT, IN level INT)
BEGIN
    DECLARE node_path TEXT;
    DECLARE base_depth INT;

    SELECT path INTO node_path FROM path_enum_nodes WHERE id = node_id;
    SET base_depth = LENGTH(node_path) - LENGTH(REPLACE(node_path, '/', ''));

    SELECT * FROM path_enum_nodes
    WHERE path LIKE CONCAT(node_path, '/%')
      AND (LENGTH(path) - LENGTH(REPLACE(path, '/', '')) = base_depth + level);
END$$

-- -- [Get Direct Ancestor] ----
DROP PROCEDURE IF EXISTS get_direct_ancestor;
CREATE PROCEDURE get_direct_ancestor(IN node_id INT)
BEGIN
    DECLARE node_path TEXT;
    DECLARE parent_path TEXT;

    SELECT path INTO node_path FROM path_enum_nodes WHERE id = node_id;

    SET parent_path = SUBSTRING_INDEX(node_path, '/', -2);
    SET parent_path = SUBSTRING_INDEX(node_path, '/', LENGTH(node_path) - LENGTH(REPLACE(node_path, '/', '')));

    SELECT * FROM path_enum_nodes
    WHERE path = SUBSTRING_INDEX(node_path, '/', LENGTH(node_path) - LENGTH(REPLACE(node_path, '/', '')) - 1);
END$$

-- -- [Get All Ancestors] ----
DROP PROCEDURE IF EXISTS get_all_ancestors;
CREATE PROCEDURE get_all_ancestors(IN node_id INT)
BEGIN
    DECLARE node_path TEXT;
    DECLARE depth INT;
    DECLARE i INT;

    SELECT path INTO node_path FROM path_enum_nodes WHERE id = node_id;

    -- Guard against invalid node_id
    IF node_path IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Node not found';
    END IF;

    SET depth = LENGTH(node_path) - LENGTH(REPLACE(node_path, '/', ''));
    SET i = 1;

    -- Use a derived table instead of a temp table
    SELECT * FROM path_enum_nodes
    WHERE path IN (
        SELECT SUBSTRING_INDEX(node_path, '/', n) AS ancestor_path
        FROM (
            SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL
            SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL
            SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL
            SELECT 10
        ) AS levels
        WHERE n < depth
    );
END;

-- -- [Get Ancestors at Level] ----
DROP PROCEDURE IF EXISTS get_ancestors_at_level;
CREATE PROCEDURE get_ancestors_at_level(IN node_id INT, IN level INT)
BEGIN
    DECLARE node_path TEXT;
    DECLARE ancestor_path TEXT;

    SELECT path INTO node_path FROM path_enum_nodes WHERE id = node_id;

    SET ancestor_path = SUBSTRING_INDEX(node_path, '/', level);

    SELECT * FROM path_enum_nodes WHERE path = ancestor_path;
END$$

-- -- [Get Siblings] ----
DROP PROCEDURE IF EXISTS get_siblings;
CREATE PROCEDURE get_siblings(IN node_id INT)
BEGIN
    DECLARE node_path TEXT;
    DECLARE parent_path TEXT;

    SELECT path INTO node_path FROM path_enum_nodes WHERE id = node_id;
    SET parent_path = SUBSTRING_INDEX(node_path, '/', LENGTH(node_path) - LENGTH(REPLACE(node_path, '/', '')) - 1);

    SELECT * FROM path_enum_nodes
    WHERE path LIKE CONCAT(parent_path, '/%')
      AND id != node_id
      AND (LENGTH(path) - LENGTH(REPLACE(path, '/', '')) = LENGTH(parent_path) - LENGTH(REPLACE(parent_path, '/', '')) + 1);
END$$

-- -- [Verify No Cycles] ----
DROP PROCEDURE IF EXISTS verify_no_cycles;
CREATE PROCEDURE verify_no_cycles()
BEGIN
    -- In path enumeration model, cycles are structurally impossible if `path` is properly maintained.
    -- This procedure ensures all paths are valid and follow format.
    SELECT COUNT(*) AS invalid_paths
    FROM path_enum_nodes
    WHERE path NOT REGEXP '^[0-9]+(\\/[0-9]+)*$';
END$$

DELIMITER ;


-- ---------------------------- [ Test Suite for path_enum_nodes ] ------------------------------

-- [Setup: Initial Tree]
-- A (1)         => 1
-- ├── B (2)     => 1/2
-- │   ├── D (4) => 1/2/4
-- │   └── E (5) => 1/2/5
-- └── C (3)     => 1/3

INSERT INTO path_enum_nodes (id, name, path) VALUES
(1, 'A', '1'),
(2, 'B', '1/2'),
(3, 'C', '1/3'),
(4, 'D', '1/2/4'),
(5, 'E', '1/2/5');

-- [Test: Add Node F under B]
CALL add_node('F', 2);
SELECT * FROM path_enum_nodes ORDER BY id;

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

-- [Test: Verify no cycles (checks path format)]
CALL verify_no_cycles();

-- [Test: Move D under C]
CALL move_node(4, 3);
SELECT * FROM path_enum_nodes ORDER BY id;

-- [Test: Try to move C under its own descendant D (should fail)]
-- Expected: error
-- CALL move_node(3, 4);

-- [Test: Delete B (and its descendants)]
Select * from path_enum_nodes;
CALL delete_node(2);
SELECT * FROM path_enum_nodes ORDER BY id;