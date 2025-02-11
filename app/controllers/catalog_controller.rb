# frozen_string_literal: true

class CatalogController < ApplicationController
  include BlacklightRangeLimit::ControllerOverride
  include BlacklightAdvancedSearch::Controller

  include Blacklight::Catalog
  include Blacklight::Marc::Catalog
  include HoldingsHelper
  include Blacklight::Ris::Catalog

  def index
    super
    load_lookup_tables
    $brand = if params.include?('lib')
               params['lib']
             else
               'neos'
             end
    $libraryname = @libraries[$brand]['name']
    $homeurl = @libraries[$brand]['url']
    $neosurl = @libraries[$brand]['neosurl']
  end

  def show
    super
    load_lookup_tables
    $brand = if params.include?('lib')
               params['lib']
             else
               'neos'
             end
    $libraryname = @libraries[$brand]['name']
    $homeurl = @libraries[$brand]['url']
    $neosurl = @libraries[$brand]['neosurl']
    @holdings = []
    @holdings = holdings(@document, :items)
    unless @holdings.nil? || @holdings.first.nil?
      @holdable = @holdings.first[:holdable]
      @bookable = @holdings.first[:bookable]
      @holdings.sort! { |a, b| b[:location].downcase <=> a[:location].downcase }
    end

    @document['title_display'] = 'Untitled document' unless @document['title_display']

    @urls = holdings(@document, :links) if @document['url_fulltext_display']

    if @document['subject_t']
      @subjects = []
      @document['subject_t'].each do |subject|
        @subjects << subject.split('--')
      end
    end

    if @document['author_addl_t']
      @additional_authors = @document['author_addl_t']
    end
  end

  configure_blacklight do |config|
    # default advanced config values
    config.advanced_search ||= Blacklight::OpenStructWithHashAccess.new
    # config.advanced_search[:qt] ||= 'advanced'
    config.advanced_search[:url_key] ||= 'advanced'
    config.advanced_search[:query_parser] ||= 'dismax'
    config.advanced_search[:form_solr_parameters] ||= {}

    # default advanced config values
    config.advanced_search ||= Blacklight::OpenStructWithHashAccess.new
    # config.advanced_search[:qt] ||= 'advanced'
    config.advanced_search[:url_key] ||= 'advanced'
    config.advanced_search[:query_parser] ||= 'dismax'
    config.advanced_search[:form_solr_parameters] ||= {}

    ## Class for sending and receiving requests from a search index
    # config.repository_class = Blacklight::Solr::Repository
    #
    ## Class for converting Blacklight's url parameters to into request parameters for the search index
    # config.search_builder_class = ::SearchBuilder
    #
    ## Model that maps search index responses to the blacklight response model
    # config.response_model = Blacklight::Solr::Response

    ## Default parameters to send to solr for all search-like requests. See also SearchBuilder#processed_parameters
    config.default_solr_params = {
      rows: 10
    }

    # solr path which will be added to solr base url before the other solr params.
    # config.solr_path = 'select'

    # items to show per page, each number in the array represent another option to choose from.
    # config.per_page = [10,20,50,100]

    ## Default parameters to send on single-document requests to Solr. These settings are the Blackligt defaults (see SearchHelper#solr_doc_params) or
    ## parameters included in the Blacklight-jetty document requestHandler.
    #
    # config.default_document_solr_params = {
    #  qt: 'document',
    #  ## These are hard-coded in the blacklight 'document' requestHandler
    #  # fl: '*',
    #  # rows: 1
    #  # q: '{!term f=id v=$id}'
    # }

    # solr field configuration for search results/index views
    config.index.title_field = 'title_display'
    config.index.display_type_field = 'format'

    # solr field configuration for document/show views
    # config.show.title_field = 'title_display'
    # config.show.display_type_field = 'format'

    # solr fields that will be treated as facets by the blacklight application
    #   The ordering of the field names is the order of the display
    #
    # Setting a limit will trigger Blacklight's 'more' facet values link.
    # * If left unset, then all facet values returned by solr will be displayed.
    # * If set to an integer, then "f.somefield.facet.limit" will be added to
    # solr request, with actual solr request being +1 your configured limit --
    # you configure the number of items you actually want _displayed_ in a page.
    # * If set to 'true', then no additional parameters will be sent to solr,
    # but any 'sniffed' request limit parameters will be used for paging, with
    # paging at requested limit -1. Can sniff from facet.limit or
    # f.specific_field.facet.limit solr request params. This 'true' config
    # can be used if you set limits in :default_solr_params, or as defaults
    # on the solr side in the request handler itself. Request handler defaults
    # sniffing requires solr requests to be made with "echoParams=all", for
    # app code to actually have it echo'd back to see it.
    #
    # :show may be set to false if you don't want the facet to be drawn in the
    # facet bar
    #
    # set :index_range to true if you want the facet pagination view to have facet prefix-based navigation
    #  (useful when user clicks "more" on a large facet and wants to navigate alphabetically across a large set of results)
    # :index_range can be an array or range of prefixes that will be used to create the navigation (note: It is case sensitive when searching values)

    config.add_facet_field 'electronic_tesim', label: 'Access', collapse: false
    config.add_facet_field 'institution_tesim', label: 'Institution', sort: 'index'
    config.add_facet_field 'location_tesim', label: 'Library', sort: 'index'
    config.add_facet_field 'lc_1letter_facet', label: 'Call Number', limit: 10
    config.add_facet_field 'format', label: 'Format', limit: 10
    config.add_facet_field 'pub_date', label: 'Publication Year', range: true
    config.add_facet_field 'author_display', label: 'Author', limit: 20
    config.add_facet_field 'subject_topic_facet', label: 'Subject', limit: 20
    config.add_facet_field 'language_facet', label: 'Language', limit: 10
    config.add_facet_field 'subject_geo_facet', label: 'Geographic Region', limit: 10
    config.add_facet_field 'subject_era_facet', label: 'Historic Period', limit: 10
    # config.add_facet_field 'owning_library_tesim', :label => 'Owning Library'

    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.add_facet_fields_to_solr_request!

    # solr fields to be displayed in the index (search results) view
    #   The ordering of the field names is the order of the display
    config.add_index_field 'author_display', label: 'Author'
    config.add_index_field 'edition_tesim', label: 'Edition'
    config.add_index_field 'author_vern_display', label: 'Author'
    config.add_index_field 'format', label: 'Format'
    config.add_index_field 'language_note_tesim', label: 'Language'
    config.add_index_field 'pub_date', label: 'Publication Year'

    # solr fields to be displayed in the show (single result) view
    #   The ordering of the field names is the order of the display
    # config.add_show_field 'title_display', :label => 'Title'
    # config.add_show_field 'title_vern_display', :label => 'Title'
    config.add_show_field 'title_addl_t', label: 'Full/Alternate Title(s)'
    # config.add_show_field 'subtitle_vern_display', :label => 'Subtitle'
    # config.add_show_field 'section_number_tesim', :label => "Section Number"
    # config.add_show_field 'section_name_tesim', :label => "Section Name"
    config.add_show_field 'alternate_display_tesim', label: 'Original'
    # config.add_show_field 'edition_tesim', :label => "Edition"
    config.add_show_field 'author_display', label: 'Author'
    config.add_show_field 'author_addl_t', label: 'Additional authors/performers'
    config.add_show_field 'author_vern_display', label: 'Author'
    # config.add_show_field 'uniform_title_tesim', :label => 'Uniform Title'
    config.add_show_field 'format', label: 'Format'
    # config.add_show_field 'language_facet', :label => 'Language'
    config.add_show_field 'publisher_tesim', label: 'Publisher'
    config.add_show_field 'published_display', label: 'Published'
    config.add_show_field 'published_vern_display', label: 'Published'
    config.add_show_field 'pub_date', label: 'Year'
    config.add_show_field 'summary_holdings_tesim', label: 'Summary of Holdings'
    # config.add_show_field 'material_type_display', :label => 'Contains'
    # config.add_show_field 'size_tesim', :label => 'Size'
    # config.add_show_field 'description_tesim', :label => 'Other Details'
    config.add_show_field 'contains_tesim', label: 'Other Physical Details'
    config.add_show_field 'moreinfo_tesim', label: 'Additional Information'
    config.add_show_field 'isbn_tesim', label: 'ISBN'
    config.add_show_field 'issn_tesim', label: 'ISSN'
    config.add_show_field 'general_note_tesim', label: 'General Note', separator: ' -- '
    config.add_show_field 'local_note_tesim', label: 'Note', separator: ' -- '
    config.add_show_field 'contents_tesim', label: 'Contents'
    config.add_show_field 'summary_tesim', label: 'Summary'
    config.add_show_field 'target_audience_note_tesim', label: 'Target Audience'
    config.add_show_field 'awards_note_tesim', label: 'Awards'
    config.add_show_field 'bibliography_note_tesim', label: 'Bibliography Note'
    config.add_show_field 'earlier_title_tesim', label: 'Earlier title'
    config.add_show_field 'later_title_tesim', label: 'Later title'
    config.add_show_field 'gmd_tesim', label: 'Object type'
    config.add_show_field 'performers_tesim', label: 'Performers'
    config.add_show_field 'title_series_t', label: 'Series'
    config.add_show_field 'publisher_number_tesim', label: 'Publisher/issue number'
    config.add_show_field 'arrangement_tesim', label: 'Organization and Arrangement'
    config.add_show_field 'time_of_event_tesim', label: 'Date and Time of Event'
    config.add_show_field 'issuing_body_tesim', label: 'Issuing Body'
    config.add_show_field 'supplementary_note_tesim', label: 'Supplement Note'
    config.add_show_field 'title_history_tesim', label: 'Title History'
    config.add_show_field 'numbering_tesim', label: 'Numbering System'
    config.add_show_field 'use_repro_tesim', label: 'Use and Reproduction'
    config.add_show_field 'language_note_tesim', label: 'Language Note'

    # config.add_show_field 'subject_topic_facet', :label => 'Subject'
    # config.add_show_field 'subject_addl_t', :label => 'Additional subject'
    # config.add_show_field 'subject_era_facet', :label => 'Time period'
    # config.add_show_field 'subject_geo_facet', :label => 'Geographic subject'

    # "fielded" search configuration. Used by pulldown among other places.
    # For supported keys in hash, see rdoc for Blacklight::SearchFields
    #
    # Search fields will inherit the :qt solr request handler from
    # config[:default_solr_parameters], OR can specify a different one
    # with a :qt key/value. Below examples inherit, except for subject
    # that specifies the same :qt as default for our own internal
    # testing purposes.
    #
    # The :key is what will be used to identify this BL search field internally,
    # as well as in URLs -- so changing it after deployment may break bookmarked
    # urls.  A display label will be automatically calculated from the :key,
    # or can be specified manually to be different.

    # This one uses all the defaults set by the solr request handler. Which
    # solr request handler? The one set in config[:default_solr_parameters][:qt],
    # since we aren't specifying it otherwise.

    config.add_search_field 'all_fields', label: 'All Fields'

    # Now we see how to over-ride Solr request handler defaults, in this
    # case for a BL "search field", which is really a dismax aggregate
    # of Solr search fields.

    config.add_search_field('title') do |field|
      # solr_parameters hash are sent to Solr as ordinary url query params.
      field.solr_parameters = { 'spellcheck.dictionary': 'title' }

      # :solr_local_parameters will be sent using Solr LocalParams
      # syntax, as eg {! qf=$title_qf }. This is neccesary to use
      # Solr parameter de-referencing like $title_qf.
      # See: http://wiki.apache.org/solr/LocalParams
      field.solr_local_parameters = {
        qf: '$title_qf',
        pf: '$title_pf'
      }
    end

    config.add_search_field('author') do |field|
      field.solr_parameters = { 'spellcheck.dictionary': 'author' }
      field.solr_local_parameters = {
        qf: '$author_qf',
        pf: '$author_pf'
      }
    end

    # Specifying a :qt only to show it's possible, and so our internal automated
    # tests can test it. In this case it's the same as
    # config[:default_solr_parameters][:qt], so isn't actually neccesary.
    config.add_search_field('subject') do |field|
      field.solr_parameters = { 'spellcheck.dictionary': 'subject' }
      field.qt = 'search'
      field.solr_local_parameters = {
        qf: '$subject_qf',
        pf: '$subject_pf'
      }
    end

    # "sort results by" select (pulldown)
    # label in pulldown is followed by the name of the SOLR field to sort by and
    # whether the sort is ascending or descending (it must be asc or desc
    # except in the relevancy case).
    config.add_sort_field 'score desc, pub_date_sort desc, title_sort asc', label: 'relevance'
    config.add_sort_field 'pub_date_sort desc, title_sort asc', label: 'year'
    config.add_sort_field 'author_sort asc, title_sort asc', label: 'author'
    config.add_sort_field 'title_sort asc, pub_date_sort desc', label: 'title'

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5

    # Configuration for autocomplete suggestor
    config.autocomplete_enabled = true
    config.autocomplete_path = 'suggest'
  end
    end
