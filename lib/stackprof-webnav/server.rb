require 'nyny'
require 'haml'
require "stackprof"
require 'net/http'
require_relative 'presenter'

module StackProf
  module Webnav
    class Server < NYNY::App
      class << self
        attr_accessor :cmd_options, :report_dump_path, :report_dump_uri, :report_dump_listing

        def presenter regenerate=false
          return @presenter unless regenerate || @presenter.nil?
          process_options
          if self.report_dump_path
            report_contents = File.open(report_dump_path).read
            report = StackProf::Report.new(Marshal.load(report_contents))
          end
          @presenter = Presenter.new(report)
        end

        private
        def process_options
          if cmd_options[:root]
            self.report_dump_listing = cmd_options[:root]
          end
        end

      end

      helpers do
        def template_path name
          File.join(__dir__, name)
        end

        def render_with_layout *args
          args[0] = template_path("views/#{args[0]}.haml")
          args[2] = (args[2] || {}).merge(escape_html: true)
          render(template_path('views/layout.haml')) { render(*args) }
        end

        def presenter
          Server.presenter
        end

        def method_url name
          "/method?name=#{URI.escape(name)}"
        end

        def file_url path
          "/file?path=#{URI.escape(path)}"
        end

        def overview_url path
          "/overview?path=#{URI.escape(path)}"
        end
      end

      get '/' do
        presenter
        if Server.report_dump_listing
          redirect_to '/listing'
        else
          redirect_to '/overview'
        end
      end

      get '/overview' do
        if params[:path]
          Server.report_dump_path = params[:path]
          Server.presenter(true)
        end
        @file = Server.report_dump_path
        @action = "overview"
        @frames = presenter.overview_frames
        render_with_layout :overview
      end

      get '/listing' do
        @dumps = presenter.listing_dumps
        @file = Server.report_dump_listing
        @action = "listing"
        render_with_layout :listing
      end

      get '/method' do
        @action = params[:name]
        @frames = presenter.method_info(params[:name])
        render_with_layout :method
      end

      get '/file' do
        path = params[:path]
        @path = path
        @data = presenter.file_overview(path)
        render_with_layout :file
      end
    end
  end
end
