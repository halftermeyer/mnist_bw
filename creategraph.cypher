CREATE CONSTRAINT darkpixel_x_y IF NOT EXISTS
FOR (px:DarkPixel) REQUIRE (px.x, px.y) IS NODE KEY;
CREATE INDEX darkpixel_x_y_index IF NOT EXISTS
FOR (px:DarkPixel) ON (px.x, px.y);

CREATE CONSTRAINT digit_id IF NOT EXISTS
FOR (px:DarkPixel) REQUIRE (px.x, px.y) IS NODE KEY;
CREATE INDEX digit_id_index IF NOT EXISTS
FOR (px:DarkPixel) ON (px.x, px.y);

// CREATE Pixel Matrix
FOREACH (col_no IN range(0, 27) |
    FOREACH (line_no IN range(0, 27) |
        CREATE (:DarkPixel {x: col_no, y: line_no})
    )
);

MATCH (left:DarkPixel), (right:DarkPixel)
WHERE left.y = right.y
AND left.x + 1 = right.x
MERGE (left)-[:VERTICAL]->(right);

MATCH (up:DarkPixel), (down:DarkPixel)
WHERE up.x = down.x
AND up.y + 1 = down.y
MERGE (up)-[:HORIZONTAL]->(down);

MATCH (nw:DarkPixel), (se:DarkPixel)
WHERE nw.x + 1 = se.x
AND nw.y + 1 = se.y
MERGE (nw)-[:DIAGONAL]->(se);

MATCH (ne:DarkPixel), (sw:DarkPixel)
WHERE ne.x - 1 = sw.x
AND ne.y + 1 = sw.y
MERGE (ne)-[:ANTI_DIAGONAL]->(sw);

// LOAD MNIST
CALL apoc.periodic.iterate("LOAD CSV
FROM 'https://drive.google.com/uc?export=download&id=1zbBjq_-jnunJq3-_2meYPBWTM-KM8UNK' AS row
FIELDTERMINATOR '|'
WITH [c IN split(substring(row[0],2,size(row[0])-4),\"), (\") | split(c, ', ') ] AS vals, toInteger(row[1]) AS y, linenumber() AS id
WITH [c IN vals | {x:toInteger(c[0]), y:toInteger(c[1])}] as vals, y, linenumber() AS id
RETURN vals, y, toInteger(id) - 1 AS id", // 0-based in original dataset
"MERGE (d:Digit {id: id})
WITH vals, y, id, d
CALL apoc.create.setLabels(d, ['Class_'+y, 'Digit'])
YIELD node
WITH vals, y, id, d
UNWIND vals AS px
MATCH (px_node:DarkPixel {x:px.x, y:px.y})
MERGE (d)-[:HAS_DARK_PIXEL]->(px_node)",
{batchSize: 1000, parallel:false});
