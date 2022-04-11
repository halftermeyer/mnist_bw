
// Project In memory to FAST RP
CALL gds.graph.project(
  'digits',
  ['Digit','DarkPixel'],
  {
    HORIZONTAL: {
      orientation: 'UNDIRECTED'
    },
    VERTICAL: {
      orientation: 'UNDIRECTED'
    },
    DIAGONAL: {
      orientation: 'UNDIRECTED'
    },
    ANTI_DIAGONAL: {
      orientation: 'UNDIRECTED'
    },
    HAS_DARK_PIXEL: {
      orientation: 'NATURAL'
    }
  }
);

//  approx 200 ms
CALL gds.fastRP.mutate('digits',
  {
    embeddingDimension: 30,
    randomSeed: 42,
    mutateProperty: 'embedding',
    iterationWeights: [0.8, 1, 1, 1]
  }
)
YIELD nodePropertiesWritten;

// Filter for KNN SIMILARITY
CALL gds.beta.graph.project.subgraph(
  'digits_only',
  'digits',
  'n:Digit',
  '*'
)
YIELD graphName, fromGraphName, nodeCount, relationshipCount;

CALL gds.graph.writeNodeProperties('digits_only', ['embedding'])
YIELD propertiesWritten;


CALL gds.knn.write('digits_only', {
    topK: 3,
    nodeProperties: ['embedding'],
    randomSeed: 42,
    concurrency: 1,
    sampleRate: 1.0,
    deltaThreshold: 0.0,
    writeRelationshipType: "SIMILAR",
    writeProperty: "score"
})
YIELD nodesCompared, relationshipsWritten, similarityDistribution
RETURN nodesCompared, relationshipsWritten, similarityDistribution.mean as meanSimilarity;


// Louvain community detection
CALL gds.graph.project(
  'digits',
  ['Digit'],
  {
    SIMILAR: {
      orientation: 'UNDIRECTED'
    }
  },
  {
    relationshipProperties: 'score'
  }
);

CALL gds.louvain.write('digits', { writeProperty: 'community' })
YIELD communityCount, modularity, modularities;

// testing query
MATCH (d:Digit)
WITH apoc.coll.flatten(collect([l IN labels(d) WHERE l <> 'Digit'])) AS labels, d.community AS community
WITH apoc.coll.frequencies(labels) AS labels, size(labels) AS community_size,  community
WITH apoc.map.fromLists([x IN labels | x.item],[x IN labels | x.count]) AS labels, community_size,  community
WITH [dig_cls IN range(0, 9) | coalesce(labels['Class_'+dig_cls], 0) ] AS labels, community_size,  community
WITH labels, community_size,  community
RETURN labels, community_size, community;
