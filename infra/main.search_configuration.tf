# Configuration of AI Search features required for CPS to do anything interesting.

# locals {
#   index_json = {
#     name = var.search_index_name,
#     "fields" : [
#       {
#         "name" : "chunk_id",
#         "type" : "Edm.String",
#         "searchable" : true,
#         "filterable" : false,
#         "retrievable" : true,
#         "stored" : true,
#         "sortable" : true,
#         "facetable" : false,
#         "key" : true,
#         "analyzer" : "keyword",
#         "synonymMaps" : []
#       },
#       {
#         "name" : "parent_id",
#         "type" : "Edm.String",
#         "searchable" : false,
#         "filterable" : true,
#         "retrievable" : true,
#         "stored" : true,
#         "sortable" : false,
#         "facetable" : false,
#         "key" : false,
#         "synonymMaps" : []
#       },
#       {
#         "name" : "chunk",
#         "type" : "Edm.String",
#         "searchable" : true,
#         "filterable" : false,
#         "retrievable" : true,
#         "stored" : true,
#         "sortable" : false,
#         "facetable" : false,
#         "key" : false,
#         "synonymMaps" : []
#       },
#       {
#         "name" : "title",
#         "type" : "Edm.String",
#         "searchable" : true,
#         "filterable" : false,
#         "retrievable" : true,
#         "stored" : true,
#         "sortable" : false,
#         "facetable" : false,
#         "key" : false,
#         "synonymMaps" : []
#       },
#       {
#         "name" : "text_vector",
#         "type" : "Collection(Edm.Single)",
#         "searchable" : true,
#         "filterable" : false,
#         "retrievable" : true,
#         "stored" : true,
#         "sortable" : false,
#         "facetable" : false,
#         "key" : false,
#         "dimensions" : 3072,
#         "vectorSearchProfile" : "vector-${var.search_index_name}-azureOpenAi-text-profile",
#         "synonymMaps" : []
#       }
#     ],
#     "scoringProfiles" : [],
#     "suggesters" : [],
#     "analyzers" : [],
#     "tokenizers" : [],
#     "tokenFilters" : [],
#     "charFilters" : [],
#     "similarity" : {
#       "@odata.type" : "#Microsoft.Azure.Search.BM25Similarity"
#     },
#     "semantic" : {
#       "defaultConfiguration" : "vector-${var.search_index_name}-semantic-configuration",
#       "configurations" : [
#         {
#           "name" : "vector-${var.search_index_name}-semantic-configuration",
#           "prioritizedFields" : {
#             "titleField" : {
#               "fieldName" : "title"
#             },
#             "prioritizedContentFields" : [
#               {
#                 "fieldName" : "chunk"
#               }
#             ],
#             "prioritizedKeywordsFields" : []
#           }
#         }
#       ]
#     },
#     "vectorSearch" : {
#       "algorithms" : [
#         {
#           "name" : "vector-${var.search_index_name}-algorithm",
#           "kind" : "hnsw",
#           "hnswParameters" : {
#             "metric" : "cosine",
#             "m" : 4,
#             "efConstruction" : 400,
#             "efSearch" : 500
#           }
#         }
#       ],
#       "profiles" : [
#         {
#           "name" : "vector-${var.search_index_name}-azureOpenAi-text-profile",
#           "algorithm" : "vector-${var.search_index_name}-algorithm",
#           "vectorizer" : "vector-${var.search_index_name}-azureOpenAi-text-vectorizer"
#         }
#       ],
#       "vectorizers" : [
#         {
#           "name" : "vector-${var.search_index_name}-azureOpenAi-text-vectorizer",
#           "kind" : "azureOpenAI",
#           "azureOpenAIParameters" : {
#             "resourceUri" : module.azure_open_ai.endpoint,
#             "deploymentId" : "text-embedding-3-large",
#             "modelName" : "text-embedding-3-large"
#           }
#         }
#       ],
#       "compressions" : []
#     }
#   }
#   indexer_json = {
#     "name" : var.search_indexer_name,
#     "description" : null,
#     "dataSourceName" : var.cps_container_name,
#     "targetIndexName" : var.search_index_name,
#     "disabled" : null,
#     "schedule" : null,
#     "parameters" : {
#       "batchSize" : null,
#       "maxFailedItems" : null,
#       "maxFailedItemsPerBatch" : null,
#       "base64EncodeKeys" : null,
#       "configuration" : {
#         "dataToExtract" : "contentAndMetadata",
#         "parsingMode" : "default"
#       }
#     },
#     "fieldMappings" : [
#       {
#         "sourceFieldName" : "metadata_storage_name",
#         "targetFieldName" : "title",
#         "mappingFunction" : null
#       }
#     ],
#     "outputFieldMappings" : [],
#     "encryptionKey" : null
#   }
#   scope               = "https://search.azure.com/.default"
#   search_api_version  = "2024-07-01"
#   search_endpoint_uri = local.search_endpoint_url
# }

# Add index to the AI Search resource
# resource "powerplatform_rest" "search_index" {
#   create = {
#     scope                = local.scope
#     url                  = "${local.search_endpoint_uri}/indexes?api-version=${local.search_api_version}"
#     method               = "POST"
#     expected_http_status = [201]
#     body                 = jsonencode(local.index_json)
#     headers = [{
#       name  = "api-key"
#       value = azurerm_search_service.ai_search.primary_key
#     }]
#   }
#   update = {
#     scope                = local.scope
#     url                  = "${local.search_endpoint_uri}/indexes/${local.index_json.name}?api-version=${local.search_api_version}"
#     method               = "PUT"
#     expected_http_status = [201]
#     body                 = jsonencode(local.index_json)
#     headers = [{
#       name  = "api-key"
#       value = azurerm_search_service.ai_search.primary_key
#     }]
#   }
#   destroy = {
#     scope                = local.scope
#     url                  = "${local.search_endpoint_uri}/indexes/${local.index_json.name}?api-version=${local.search_api_version}"
#     method               = "DELETE"
#     expected_http_status = [201]
#     headers = [{
#       name  = "api-key"
#       value = azurerm_search_service.ai_search.primary_key
#     }]
#   }
# }

# TODO add a proper polling mechanism instead of wait
# resource "time_sleep" "wait_for_index" {
#   create_duration = "120s" # Wait for 120 seconds

#   depends_on = [powerplatform_rest.search_index]
# }

# Add indexer to the AI Search resource
# resource "powerplatform_rest" "search_indexer" {
#   # TODO remove the endpoint dependencies once this file is running in the second pass (it won't be necessary)
#   depends_on = [azurerm_private_endpoint.primary, azurerm_private_endpoint.failover, time_sleep.wait_for_index]
#   create = {
#     scope                = local.scope
#     url                  = "${local.search_endpoint_uri}/indexers?api-version=${local.search_api_version}"
#     method               = "POST"
#     expected_http_status = [201]
#     body                 = jsonencode(local.indexer_json)
#     headers = [{
#       name  = "api-key"
#       value = azurerm_search_service.ai_search.primary_key
#     }]
#   }
#   update = {
#     scope                = local.scope
#     url                  = "${local.search_endpoint_uri}/indexers/${var.search_indexer_name}?api-version=${local.search_api_version}"
#     method               = "PUT"
#     expected_http_status = [201]
#     body                 = jsonencode(local.indexer_json)
#     headers = [{
#       name  = "api-key"
#       value = azurerm_search_service.ai_search.primary_key
#     }]
#   }
#   destroy = {
#     scope                = local.scope
#     url                  = "${local.search_endpoint_uri}/indexers/${var.search_indexer_name}?api-version=${local.search_api_version}"
#     method               = "DELETE"
#     expected_http_status = [201]
#     headers = [{
#       name  = "api-key"
#       value = azurerm_search_service.ai_search.primary_key
#     }]
#   }
# }
