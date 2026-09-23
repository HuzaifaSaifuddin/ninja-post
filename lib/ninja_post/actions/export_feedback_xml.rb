# frozen_string_literal: true

require "rexml/document"
require "fileutils"

module NinjaPost
  module Actions
    class ExportFeedbackXml
      DEFAULT_DIR = File.join(APP_ROOT, "tmp", "feedbacks_export")

      SQL = <<~SQL
        SELECT u.login       AS owner_login,
               f.comment,
               f.feedback_type,
               p.rating_avg  AS rating
        FROM feedbacks f
        JOIN users u ON u.id = f.owner_id
        LEFT JOIN posts p ON p.id = f.post_id
        ORDER BY f.id
      SQL

      def self.call(dir: DEFAULT_DIR) = new(dir: dir).call

      def initialize(dir:)
        @dir = dir
      end

      def call
        rows = DB.fetch(SQL).all
        path = build_path

        FileUtils.mkdir_p(@dir)
        File.write(path, to_xml(rows))

        path
      end

      private

      def build_path
        File.join(@dir, "feedbacks-#{Time.now.strftime('%Y-%m-%d')}.xml")
      end

      def to_xml(rows)
        doc = REXML::Document.new
        doc << REXML::XMLDecl.new("1.0", "UTF-8")

        root = doc.add_element("feedbacks", "generated_at" => Time.now.iso8601)

        rows.each do |row|
          feedback = root.add_element("feedback")
          feedback.add_element("owner_login").text = row[:owner_login]
          feedback.add_element("comment").text = row[:comment]
          # BigDecimal#to_s defaults to scientific notation ("0.35e1"); "F"
          # forces plain fixed-point ("3.5"). nil (user-feedback) -> empty tag.
          feedback.add_element("rating").text = row[:rating]&.to_s("F")
          feedback.add_element("feedback_type").text = row[:feedback_type]
        end

        # No `indent:` here on purpose: REXML's pretty-printer pads element
        # TEXT with the indentation whitespace, which becomes part of the
        # value itself (a login or comment would come back with stray
        # leading/trailing whitespace). Compact output keeps values exact.
        out = String.new
        doc.write(out)
        out
      end
    end
  end
end
