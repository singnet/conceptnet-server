(define-module (conceptnet) 
                #:export(
                    cn5-print-conceptnet-server-host
                    cn5-set-conceptnet-server-host
                    cn5-print-query-limit
                    cn5-set-query-limit
                    cn5-enable-central-topic
                    cn5-disable-central-topic
                    cn5-query
                    cn5-enable-cache
                    cn5-disable-cache
                    cn5-clear-cache))

(use-modules (web client) ;;; allows to use the http-get procedure
             (rnrs bytevectors) ;;; allows to convert bytevector responses from the conceptnet server to string
             (ice-9 receive) ;;; allows to set more than one output parameter in output variables
             (ice-9 format) ;;; allows to easily forma strings
             (ice-9 i18n) ;;; used to manipulate and convert text considering locale
             (ice-9 regex) ;;; regex handling
             (ice-9 optargs) ;;; to allow define optional paramters
             (srfi srfi-1) ;;; for fold function
             (json) ;;; json opperations
             (opencog) ;;; opencog core
             (opencog nlp) ;;; nlp related functs
             (opencog nlp lg-dict) ;;; 
             (opencog nlp relex2logic) ;;; relex related funcs 
             (opencog nlp chatbot)) ;;; chatbot related funcs

;;; utils for guile editing
(use-modules (ice-9 readline))
(activate-readline)

"
    # GUILE-JSON LIBRARY

        It is very important to note that in order for the guile-json module to work correctly,
        the https://github.com/aconchillo/guile-json must be installed.

        ## INSTALATION

        In order to install this library do the following.

        ´´´
        git clone https://github.com/aconchillo/guile-json.git;\
        cd guile-json;\
        sudo apt-get -y install autoconf;\
        autoreconf -vif;\
        ./configure --prefix=/usr/local --libdir=/usr/local/lib;\
        make;\
        sudo make install
        ´´´

        Make sure that the --prefix=/usr is pointing to your guile instalation folder. The procedure
        will show more options when those are required.

    # CONCEPTNET 5 OPENCOG MODULE

        This module allows to perform queries into a conceptnet5 server. It exposes
        procedures described bellow.

        ´´´
        (cn5-print-conceptnet-server-host) - This procedure prints the current server address 
        ´´´
        
        ´´´
        (cn5-set-conceptnet-server-host address #:key (port 80)) - This method allows to set the server host address that will 
        be used to perform queries.

            #:port - allows to define which port will be used to access the server
        ´´´

        ´´´
        (cn5-print-query-limit) - This method allows to print the configure query limit - how many results will be returned from a request
        ´´´

        ´´´
        (cn5-set-query-limit limit) - This method allows to set the query limit - how many results will be returned from a request
        ´´´

        ´´´
        (cn5-enable-central-topic) - Enable the central topic search in generated phrase nodes
        ´´´

        ´´´
        (cn5-disable-central-topic) - Disable the central topic search in generated phrase nodes
        ´´´

        ´´´
        (cn5-enable-cache) - Enable the caching mechanism
        ´´´

        ´´´
        (cn5-disable-cache) - Disable the caching mechanism
        ´´´

        ´´´
        (cn5-clear-cache) - Clear the current cashed data
        ´´´

        ´´´
        (cn5-query node #:key (language #f) (languageFilter #f) (whiteList #f) (blackList #f) (debug #f)) 
        
            * Query the concepnet server and return a list of PredicateNodes representing each found concept. 
            * A found concept is represented as a WordNode or a PhraseNode.
            * The central topic of a PhraseNode can also be extracted which generated another PhraseNode to hold it. 
            * The central topic will be extracted only if the (cn5-enable-central-topic) is called before calling this method.

            #:language - It is a string that allows to set in which language the query will be performed, 
                         otherwise it will be performed in english. It should be defined as a string 
                         representing the language code. For example, \"en\" \"jp\" \"pt\" are valid language code strings.

            #:languageFilter - It is a LIST that allows to define which languages will be returned from the query results.
                               It should contain language codes. For example, '(\"en\" \"jp\" \"pt\") is a valid language filter.

            #:whiteList - It is a LIST that allows to define which assertion types will be choosen from the query results. 
                          All other types are ignored.
                          It should define conceptnet assertion types. For example, '(\"IsPartOf\" \"IsA\") is a valid whiteList.

            #:blackList - It is a LIST that allows to define which assertion types will be ignored from the query results.
                          It should define conceptnet assertion types. For example, '(\"IsPartOf\" \"IsA\") is a valid blackList.

            #:debug - It is a boolean that allows to define when the query status will be printed in the terminal to the user.
                      A query status is composed by the following fields.
                    
                        * query language
                        * language filter
                        * white list
                        * black list
        ´´´

    # USAGE EXAMPLES

        ´´´
        (cn5-query (ConceptNode \"tree\")) 
                    -> will return an atomese code for all the obtained results.
        
        (cn5-query (ConceptNode \"tree\") #:language \"en\") 
                    -> will return an atomese code for all the obtained results that are in english.

        (cn5-query (ConceptNode \"tree\") #:language \"en\" #:whiteList '(\"IsA\")) 
                    -> will return an atomese code for all the obtained results that are in english where the relation type is equal to \"IsA\"

        (cn5-query (ConceptNode \"tree\") #:language \"en\" #:blackList '(\"IsA\"))
                    -> will return an atomese code for all the obtained results that are in english except the ones where the relation type is equal to \"IsA\"

        (cn5-query (ConceptNode \"tree\") #:language \"en\" #:whiteList '(\"IsA\" \"PartOf\") #:blackList '(\"IsA\"))
                    -> will return an atomese code for all the obtained results that are in english,
                       where the relation types are \"IsA\" or \"PartOf\"
                       except those who are \"IsA\"

        (cn5-query (ConceptNode \"tree\") #:debug #t)
                    -> will trigger the debug flag and print the query status.
        ´´´
"

; ----------------------------------------------------------------------
; Logger setup

;;; (cn5-cache)
;;; Used to store known about already performed queries
(define cn5-cache '())

;;; (cn5-use-cache)
;;; This variable is used to enable and disable the usage of cache
(define cn5-use-cache #t)

;;; (cn5-enable-cache)
;;; This method enables the caching mechanism
(define (cn5-enable-cache)
    (set! cn5-use-cache #t)
)

;;; (cn5-disable-cache)
;;; This method disables the caching mechanism
(define (cn5-disable-cache)
    (set! cn5-use-cache #f)
)

;;; (cn5-clear-cache)
;;; This method clears the all the data inside the caching structure
(define (cn5-clear-cache)
    (set! cn5-cache '())
)

;;; (cn5-concept-net-server-address)
;;; Default conceptnet server address.
(define cn5-concept-net-server-address "http://api.conceptnet.io/")

;;; (cn5-query-limit)
;;; Default query limit size
(define cn5-query-limit 10000)

;;; (cn5-seek-central-topic)
;;; Central topic search flag
(define cn5-seek-central-topic #f)

;;; (cn5-black-list)
;;; Black list containing the unwanted relation types
(define cn5-black-list '())

;;; (cn5-white-list)
;;; White list containing the wanted relation types
(define cn5-white-list '())

;;; (cn5-edges-list)
;;; Language filter containing all languages for the performed query
(define cn5-language-filter '())

;;; (cn5-print-query-limit)
;;; print the current configured query limit
(define (cn5-print-query-limit)
    (format #f "Query limit: ~a" cn5-query-limit)
)

;;; (cn5-set-query-limit)
;;; set the query limit
(define (cn5-set-query-limit limit)
    (set! cn5-query-limit limit)
)

;;; (cn5-enable-central-topic)
;;; set the central topic search flag to true
(define (cn5-enable-central-topic)
    (set! cn5-seek-central-topic #t)
)

;;; (cn5-disable-central-topic)
;;; set the central topic search flag to false
(define (cn5-disable-central-topic)
    (set! cn5-seek-central-topic #f)
)

;;; (cn5-print-conceptnet-server-host)
;;; print the current configured address to access the concepnet server
(define (cn5-print-conceptnet-server-host)
    (format #f "Current configured server: ~a" cn5-concept-net-server-address)
)

;;; (cn5-set-conceptnet-server-host)
;;; This procedure set the server host address and port
(define* (cn5-set-conceptnet-server-host address #:key (port 80))
    (let 
        ;;; let the full_address be the free api
        ((full_address ""))
        (begin
            ;;; properly assign the host address string
            (set! full_address (format #f "http://~a:~a/" address port))

            ;;; set the global concept net server address
            (set! cn5-concept-net-server-address full_address)

            ;;; tell the user that the opperation was successfull
            (format #f "Host address set to: ~a" full_address)
        )
    )
)

;;; (cn5-parse-relation-type)
;;; This method is used to parse the relation type of concepnet from "/r/RelationType" to 
;;; just "RelationType". In other words, it removes the /r/ and returns a string containing
;;; only the relation.
(define (cn5-parse-relation-type conceptNet5Rel)
    (let 
        (
            (parsed_relation (string-split conceptNet5Rel #\/))
        )

        (list-ref parsed_relation (- (length parsed_relation) 1))
    )
)

;;; (cn5-handle-query-string)
;;; This method transforms the query command into an accepted format for conceptnet.
(define (cn5-handle-query-string queryString)
    (let
        (
            (str (string-locale-downcase queryString))
        )
        (set! str (regexp-substitute/global #f "[ \t]+" str 'pre "_" 'post))
        str
    )
)

;;; (cn5-query-concept-net)
;;; Allows to perform a query to the configured conceptnet server.
(define (cn5-query-concept-net query)
    (let ((server_addres cn5-concept-net-server-address))
        (begin
            (set! server_addres (format #f "~a~a" server_addres query))
            (json-string->scm 
                (utf8->string 
                    (receive (head query_result) 
                        (http-get server_addres) 
                        query_result
                    )
                )
            )
        )
    )
)

;;; (cn5-normalize-filter)
;;; transform a filter list into a map to allow fast search when looking for elements
(define (cn5-normalize-filter filterList)
    (fold
        (lambda (el outputList)
            (set! filterList (acons el el outputList))
            filterList
        )
        '()
        filterList
    )
)

;;; (cn5-create-evaluation-link)
;;; this procedure receives a JSON representing a conceptnet assertion and transform it into atomese.
;;; it is used as a fold procedure.
(define (cn5-create-evaluation-link 
            node
            queryTerm
            relation_type
            start_node_label
            start_node_language
            end_node_label
            end_node_language
            relation_weight
            languageFilter
            whiteList
            blackList)
    (let 
        ( 
            ( insert_element #t )
            ( output_list '() )
        )
        (begin
            ;;; check if the white_list filter is available
            (if (list? whiteList)
                ;;; if not in the white_list do not transform this element into atomese
                (if (not (assoc-ref whiteList relation_type))
                    (set! insert_element #f)
                )
            )

            (if (list? blackList)
                ;;; if in the black_list do not transform this element into atomese
                (if (assoc-ref blackList relation_type)
                    (set! insert_element #f)
                )
            )

            (if (list? languageFilter)
                ;;; if not in the allowed languages do not transform this element into atomese
                (if (or 
                        (eq? (assoc-ref languageFilter start_node_language) #f)
                        (eq? (assoc-ref languageFilter end_node_language) #f)
                    )
                    (set! insert_element #f)
                )
            )

            ;;; check if element will be inserted
            (if (eq? insert_element #t)
                ;;; if everything ok, then insert into the output_list
                (let 
                    (
                        (generated_edge (cn5-generate-edge 
                                            node
                                            queryTerm
                                            relation_type 
                                            start_node_label 
                                            end_node_label 
                                            relation_weight))
                    )
                    (if (list? generated_edge)
                        (append output_list generated_edge)
                        (append output_list (list generated_edge))
                    )
                )

                ;;; else return the current output_list without any modification
                output_list                 
            )
        )
    )
)

;;; (cn5-get-edge-same-syn-class queryTerm startNodeLabel endNodeLabel relationType relationWeight start) 
;;; seek for the central term of a sentence if the find-central-term flag is set to true and returns a EvaluationLink containing it
(define (cn5-get-edge-same-syn-class queryTerm startNodeLabel endNodeLabel relationType relationWeight start) 
    (let 
        (
            (same_syntactic_class_word 
                (if (eq? start #t)
                    (cn5-get-same-syntactic-class queryTerm startNodeLabel)
                    (cn5-get-same-syntactic-class queryTerm endNodeLabel)
                )
            )
        )
        (if (list? same_syntactic_class_word)
            ;;; return new valid link
            (let 
                (
                    (same_syntactic_class_start_word_edge 
                        (cog-set-tv! ;;; if true returns a evaluationlink
                            (EvaluationLink 
                                (PredicateNode relationType)            
                                (if (eq? start #t)
                                    (begin
                                        (ListLink
                                            (WordNode (car same_syntactic_class_word))                              
                                            (WordNode endNodeLabel)
                                        )
                                    )
                                    (begin
                                        (ListLink
                                            (WordNode startNodeLabel)                              
                                            (WordNode (car same_syntactic_class_word))
                                        )
                                    )
                                )
                            )
                            (cog-new-stv relationWeight relationWeight)
                        )
                    )
                )

                ;;; insert only if the founded term is different from the query term to avoid
                ;;; duplicated vertexes
                (if (eq? start #t)
                    (if (eq? (string=? (car same_syntactic_class_word) endNodeLabel) #f)
                        (list same_syntactic_class_start_word_edge)
                    )
                    (if (eq? (string=? (car same_syntactic_class_word) startNodeLabel) #f)
                        (list same_syntactic_class_start_word_edge)
                    )
                )
            )
            ;;; return false since no matching syntactic relation was found
            #f
        )
    )
)

;;; (cn5-generate-edge)
;;; return a EvaluationLink containing the startnode label and the end node label. Also can include
;;; the central tendendy if the flag is true
(define (cn5-generate-edge
            node
            queryTerm
            relationType
            startNodeLabel
            endNodeLabel
            relationWeight)
    (let 
        (
            (query_length (length (string-split queryTerm #\ )))
        )
        (begin
            (let
                (
                    (generated_edge 
                        (EvaluationLink
                            (PredicateNode relationType)
                            (if (equal? queryTerm startNodeLabel) 
                                (begin
                                    (ListLink
                                        node
                                        (if (> (length (string-split endNodeLabel #\ )) 1)
                                            (PhraseNode endNodeLabel)
                                            (WordNode endNodeLabel)
                                        )
                                    )
                                ) 
                                (begin ; (equal? queryTerm endNodeLabel)
                                    (ListLink
                                        (if (> (length (string-split endNodeLabel #\ )) 1)
                                            (PhraseNode endNodeLabel)
                                            (WordNode endNodeLabel)
                                        )
                                        node
                                    )
                                )
                            )
			    (stv relationWeight relationWeight)
                        )
                    )
                )

                ;;; returns the generated edge
                generated_edge
            )
        )
    )
)

;;; (cn5-query)
;;; Performs a query into a conceptnet5 server and generate atomese from the returned assertions.
(define* (cn5-query
            node ;;; node used as the query seed
                #:key ;;; marks optional parameters bellow 
                    (language #f);;; language to perform the query
                    (languageFilter #f) ;;; language filter for query results
                    (whiteList #f) ;;; whitelisted relations
                    (blackList #f) ;;; blacklisted relations
                    (debug #f) ;;; debug flag for console print
                    )
    (let 
        (  
            ;;; inputs
            (concept_name (cog-name node))

            ;;; variables
            (concept_string_lower_case "")
            (query_language "")
            (query_string "")
            (query_results_json '())
            (query_term_list '())
            (edges_list '())

            ;;; constants
            (concept_prefix "c")
            (default_language "en")
            (language_filter languageFilter)
            (white_list whiteList)
            (black_list blackList)
            (query_limit cn5-query-limit)
            (query_offset 0)
	        (inserted_edges 0)
            (answer '())
            (cached-element (assoc-ref cn5-cache (cog-name node)))
        )
        (if (not cached-element)
            (begin
                ;;; normalize the query string to fit concept net standard
                (set! concept_string_lower_case (cn5-handle-query-string concept_name))

                ;;; setup the query language
                (if (eq? language #f)
                    ;;; set default language if none was specified
                    (set! query_language default_language)

                    ;;; set the specified language
                    (set! query_language language)
                )

                ;;; set the query string
                (set! query_string (format #f "~a/~a/~a?offset=~a&limit=~a" concept_prefix query_language concept_string_lower_case query_offset query_limit))

                ;;; perform the query to the conceptnet5, it returns a JSON association list
                (set! query_results_json (cn5-query-concept-net query_string) )

                ;;; get the elements under the 'edges' key from the returned JSON
                (set! edges_list (vector->list (assoc-ref query_results_json "edges")) )

                ;;; normalize filters to lowercase to facilitate comparison
                (if (list? language_filter)
                    (set! cn5-language-filter (cn5-normalize-filter language_filter)))

                (if (list? white_list)
                    (set! cn5-white-list (cn5-normalize-filter white_list)))

                (if (list? black_list)
                    (set! cn5-black-list (cn5-normalize-filter black_list)))

                ;;; print query parameters and how it will be performed for debug purposes
                (if (eq? debug #t)
                    (begin
                        (newline)
                        (display (format #f "query language: ~a" query_language))(newline)
                        (display (format #f "language filters: ~a" language_filter))(newline)
                        (display (format #f "white list: ~a" white_list))(newline)
                        (display (format #f "black list: ~a" black_list))(newline)
                        (newline)
                    )
                )

                (for-each
                    (lambda (edge)
                        (let* 
                            (
                                ( relation_type (cn5-parse-relation-type (assoc-ref (assoc-ref edge "rel") "@id") ) ) 
                                ( start_node_label (assoc-ref (assoc-ref edge "start") "label") )
                                ( start_node_language (assoc-ref (assoc-ref edge "start") "language") )
                                ( end_node_label (assoc-ref (assoc-ref edge "end") "label") )
                                ( end_node_language (assoc-ref (assoc-ref edge "end") "language") )
                                ( relation_weight (- 1.0 (exact->inexact (/ 1 (assoc-ref edge "weight")) ) ) )
                            )
                            (begin
                                ;;; check if the relation weight of this edge has 
                                ;;; a significant value, otherwise ignore it
                                (if (> relation_weight 0.25)
                                    (begin
                                        (set! answer 
                                            (append answer 
                                                (list 
                                                    ;;; create the evaluation link
                                                    (cn5-create-evaluation-link 
                                                        node
                                                        concept_string_lower_case
                                                        relation_type
                                                        start_node_label
                                                        start_node_language
                                                        end_node_label
                                                        end_node_language
                                                        relation_weight
                                                        cn5-language-filter
                                                        cn5-white-list
                                                        cn5-black-list
                                                    )
                                                )
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                    edges_list
                )
        
                ;;; set cache with the answer
                (if (eq cn5-use-cache #t)
                    (set! cn5-cache (acons concept_name answer cn5-cache))
                )
                
                ;;; returns the created edges list
                answer            
            ) ;;; begin
            cached-element
        ) ;;; end if
    )
)

;;; (cn5-get-list-index l el)
;;; return the index of the found element given a list
(define (cn5-get-list-index l el)
    (if (null? l)
        -1
        (if (string=? (car l) el)
            0
            (let ((result (cn5-get-list-index (cdr l) el)))
                (if (= result -1)
                    -1
                    (1+ result))))))

;;; (cn5-get-same-syntactic-class term phrase)
;;; return a list containg the word in the phrase that is from the same sintactic class as the term
(define (cn5-get-same-syntactic-class term phrase)
    (let 
        ( 
            (syntactic_class_term #f)
            (syntactic_class_and_words_matrix (cn5-get-syntactic-classes phrase))
            (words_phrase_list '())
            (syntactic_class_phrase_list '())
            (syntactic_class_found_index -1)
            ( output_list '() )
        )
        ;;; get the syntactic class of the input term
        (set! syntactic_class_term (car (car (cdr (cn5-get-syntactic-classes term)))))

        ;;; get the syntactic classes from the syntactic classes and words matrix
        (set! syntactic_class_phrase_list (car (cdr syntactic_class_and_words_matrix)))

        ;;; get all words from the syntactic classes and words matrix
        (set! words_phrase_list (car syntactic_class_and_words_matrix))

        ;;; try to find the term syntactic class inside the input phrase
        (set! syntactic_class_found_index (cn5-get-list-index syntactic_class_phrase_list syntactic_class_term))
                    
        ;;; if element was found insert it into the output list
        (if (> syntactic_class_found_index -1)
            (set! output_list (append output_list (list (list-ref words_phrase_list syntactic_class_found_index))))
        )

        ;;; if the output list has an element return it, otherwise return false
        (if (> (length output_list) 0)
            output_list
            #f
        )
    )
)

;;; (cn5-get-syntactic-classes sentence)
;;; return two lists. the first containes all the sentences words and the second all the sintactic class for each word
(define (cn5-get-syntactic-classes sentece)
    (cn5-get-lemma-and-syntactic-class (cn5-get-word-instance-nodes sentece))
)

;;; (cn5-get-syntactic-class)
;;; returns a list of WordInstanceNodes for each word in the sentence
(define (cn5-get-word-instance-nodes sentence)
    (begin
        ;;; configure the server to access the relex server properly
        (set-relex-server-host)

        ;;; release the last parsed sentence from the relex
        (release-new-parsed-sents)

        ;;; parse the input term with the relex server
        (relex-parse sentence)
        
        (let
            (
                ;;; get all WordInstanceNodes for each word in the parsed sentence
                (nodes_words (cog-chase-link 'WordInstanceLink 'WordInstanceNode (car (cog-chase-link 'ParseLink 'ParseNode (car (get-new-parsed-sentences))))))
            )
            (begin
                nodes_words
            )
        )
    )
)

;;; (cn5-get-lemma-and-syntactic-class )
;;; get all lemmas and sintactic classes from a set of WordInstanceNodes
(define* (cn5-get-lemma-and-syntactic-class 
            wordInstanceNodesList
                #:key
                    (filter #f)
                )
    (let
        (
            (output_lemmas '())
            (output_syntactic_class '())
        )

        (for-each
            (lambda (wordInstanceNode)
                (let
                    (
                        (reference_link (cog-name (car (cog-chase-link 'ReferenceLink 'WordNode wordInstanceNode))))
                    )
                    (if (eq? (string=? reference_link "###LEFT-WALL###") #f)
                        (let
                            (
                                (lemma (cog-name (car (cog-chase-link 'LemmaLink 'WordNode wordInstanceNode))))
                                (syntactic_class (cog-name (car (cog-chase-link 'PartOfSpeechLink 'DefinedLinguisticConceptNode wordInstanceNode))))
                                (insert #t)
                            )
                            (begin 
                                (if (list? filter)
                                    (if (eq? (member syntactic_class filter) #f)
                                        (set! insert #f)
                                    )
                                )

                                (if (eq? insert #t)
                                    (begin
                                        (set! output_lemmas (append output_lemmas (list lemma)))
                                        (set! output_syntactic_class (append output_syntactic_class (list syntactic_class)))
                                    )
                                )
                            )
                        )
                    )
                )
            )
            wordInstanceNodesList
        )

        (list output_lemmas output_syntactic_class)
    )
)