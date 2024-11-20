# frozen_string_literal: true

require "test_helper"

module ProductTaxonomy
  class AttributeTest < ActiveSupport::TestCase
    test "load_from_source loads attributes from deserialized YAML" do
      attributes_yaml_content = <<~YAML
        ---
        base_attributes:
        - id: 1
          name: Color
          description: Defines the primary color or pattern, such as blue or striped
          friendly_id: color
          handle: color
          values:
          - color__black
        - id: 3
          name: Pattern
          description: Describes the design or motif of a product, such as floral or striped
          friendly_id: pattern
          handle: pattern
          values:
          - pattern__abstract
        extended_attributes:
        - id: 4
          name: Clothing Pattern
          description: Describes the design or motif of a product, such as floral or striped
          friendly_id: clothing_pattern
          handle: clothing_pattern
          values_from: pattern
      YAML
      values_yaml_content = <<~YAML
        - id: 1
          name: Black
          friendly_id: color__black
          handle: color__black
        - id: 2
          name: Abstract
          friendly_id: pattern__abstract
          handle: pattern__abstract
      YAML
      values_model_index = Value.load_from_source(source_data: YAML.safe_load(values_yaml_content))
      attributes = Attribute.load_from_source(
        source_data: YAML.safe_load(attributes_yaml_content),
        values: values_model_index.hashed_by(:friendly_id),
      ).hashed_by(:friendly_id)

      assert_equal 3, attributes.size

      color = attributes["color"]
      assert_instance_of Attribute, color
      assert_equal "color", color.handle
      assert_instance_of Array, color.values
      assert_instance_of Value, color.values.first
      assert_equal ["color__black"], color.values.map(&:friendly_id)

      pattern = attributes["pattern"]
      assert_instance_of Attribute, pattern
      assert_equal "pattern", pattern.handle
      assert_instance_of Array, pattern.values
      assert_instance_of Value, pattern.values.first
      assert_equal ["pattern__abstract"], pattern.values.map(&:friendly_id)

      clothing_pattern = attributes["clothing_pattern"]
      assert_instance_of ExtendedAttribute, clothing_pattern
      assert_equal "clothing_pattern", clothing_pattern.handle
      assert_instance_of Array, clothing_pattern.values
      assert_instance_of Value, clothing_pattern.values.first
      assert_equal ["pattern__abstract"], clothing_pattern.values.map(&:friendly_id)
    end

    test "load_from_source raises an error if the source YAML does not follow the expected schema" do
      yaml_content = <<~YAML
        ---
        foo=bar
      YAML

      assert_raises(ArgumentError) { Attribute.load_from_source(source_data: YAML.safe_load(yaml_content), values: {}) }
    end

    test "load_from_source raises an error if the source data contains incomplete attributes" do
      yaml_content = <<~YAML
        ---
        base_attributes:
        - id: 1
          name: Color
        extended_attributes: []
      YAML

      error = assert_raises(ActiveModel::ValidationError) do
        Attribute.load_from_source(source_data: YAML.safe_load(yaml_content), values: {})
      end
      expected_errors = {
        friendly_id: [{ error: :blank }],
        handle: [{ error: :blank }],
        description: [{ error: :blank }],
        values: [{ error: :blank }],
      }
      assert_equal expected_errors, error.model.errors.details
    end

    test "load_from_source raises an error if the source data contains attributes with empty values" do
      yaml_content = <<~YAML
        ---
        base_attributes:
        - id: 1
          name: Color
          description: Defines the primary color or pattern, such as blue or striped
          friendly_id: color
          handle: color
          values: []
        extended_attributes: []
      YAML

      error = assert_raises(ActiveModel::ValidationError) do
        Attribute.load_from_source(source_data: YAML.safe_load(yaml_content), values: {})
      end
      expected_errors = {
        values: [{ error: :blank }],
      }
      assert_equal expected_errors, error.model.errors.details
    end

    test "load_from_source raises an error if the source data contains attributes with values that are not found" do
      yaml_content = <<~YAML
        ---
        base_attributes:
        - id: 1
          name: Color
          description: Defines the primary color or pattern, such as blue or striped
          friendly_id: color
          handle: color
          values:
          - foo
        extended_attributes: []
      YAML

      error = assert_raises(ActiveModel::ValidationError) do
        Attribute.load_from_source(source_data: YAML.safe_load(yaml_content), values: {})
      end
      expected_errors = {
        values: [{ error: :not_found }],
      }
      assert_equal expected_errors, error.model.errors.details
    end

    test "load_from_source raises an error if the source data contains incomplete extended attributes" do
      yaml_content = <<~YAML
        ---
        base_attributes: []
        extended_attributes:
        - id: 2
          name: Clothing Color
          description: Defines the primary color or pattern, such as blue or striped
      YAML

      error = assert_raises(ActiveModel::ValidationError) do
        Attribute.load_from_source(source_data: YAML.safe_load(yaml_content), values: {})
      end
      expected_errors = {
        friendly_id: [{ error: :blank }],
        handle: [{ error: :blank }],
        values_from: [{ error: :not_found }],
      }
      assert_equal expected_errors, error.model.errors.details
    end

    test "load_from_source raises an error if the source data contains extended attributes with values_from that is not found" do
      yaml_content = <<~YAML
        ---
        base_attributes: []
        extended_attributes:
        - id: 2
          name: Clothing Color
          description: Defines the primary color or pattern, such as blue or striped
          handle: clothing_color
          friendly_id: clothing_color
          values_from: foo
      YAML

      error = assert_raises(ActiveModel::ValidationError) do
        Attribute.load_from_source(source_data: YAML.safe_load(yaml_content), values: {})
      end
      expected_errors = {
        values_from: [{ error: :not_found }],
      }
      assert_equal expected_errors, error.model.errors.details
    end

    test "load_from_source raises an error if the source data contains duplicate friendly IDs" do
      attributes_yaml_content = <<~YAML
        ---
        base_attributes:
        - id: 1
          name: Color
          description: Defines the primary color or pattern, such as blue or striped
          friendly_id: color
          handle: color
          values:
          - color__black
        - id: 2
          name: Pattern
          description: Describes the design or motif of a product, such as floral or striped
          friendly_id: color
          handle: pattern
          values:
          - pattern__abstract
        extended_attributes: []
      YAML
      values_yaml_content = <<~YAML
        - id: 1
          name: Black
          friendly_id: color__black
          handle: color__black
        - id: 2
          name: Abstract
          friendly_id: pattern__abstract
          handle: pattern__abstract
      YAML
      values_model_index = Value.load_from_source(source_data: YAML.safe_load(values_yaml_content))

      error = assert_raises(ActiveModel::ValidationError) do
        Attribute.load_from_source(
          source_data: YAML.safe_load(attributes_yaml_content),
          values: values_model_index.hashed_by(:friendly_id),
        )
      end
      expected_errors = {
        friendly_id: [{ error: :taken }],
      }
      assert_equal expected_errors, error.model.errors.details
    end

    test "load_from_source raises an error if the source data contains an invalid ID" do
      attributes_yaml_content = <<~YAML
        ---
        base_attributes:
        - id: foo
          name: Color
          description: Defines the primary color or pattern, such as blue or striped
          friendly_id: color
          handle: color
          values:
          - color__black
        extended_attributes: []
      YAML
      values_yaml_content = <<~YAML
        - id: 1
          name: Black
          friendly_id: color__black
          handle: color__black
      YAML
      values_model_index = Value.load_from_source(source_data: YAML.safe_load(values_yaml_content))

      error = assert_raises(ActiveModel::ValidationError) do
        Attribute.load_from_source(
          source_data: YAML.safe_load(attributes_yaml_content),
          values: values_model_index.hashed_by(:friendly_id),
        )
      end
      expected_errors = {
        id: [{ error: :not_a_number, value: "foo" }],
      }
      assert_equal expected_errors, error.model.errors.details
    end

    test "localized attributes are returned correctly" do
      fr_yaml = <<~YAML
        fr:
          attributes:
            color:
              name: "Nom en français"
              description: "Description en français"
      YAML
      es_yaml = <<~YAML
        es:
          attributes:
            color:
              name: "Nombre en español"
              description: "Descripción en español"
      YAML
      Dir.expects(:glob)
        .with(File.join(DATA_PATH, "localizations", "attributes", "*.yml"))
        .returns(["fake/path/fr.yml", "fake/path/es.yml"])
      YAML.expects(:safe_load_file).with("fake/path/fr.yml").returns(YAML.safe_load(fr_yaml))
      YAML.expects(:safe_load_file).with("fake/path/es.yml").returns(YAML.safe_load(es_yaml))

      attribute = Attribute.new(
        id: 1,
        name: "Raw name",
        description: "Raw description",
        friendly_id: "color",
        handle: "color",
        values: [],
      )
      assert_equal "Raw name", attribute.name
      assert_equal "Raw description", attribute.description
      assert_equal "Raw name", attribute.name(locale: "en")
      assert_equal "Raw description", attribute.description(locale: "en")
      assert_equal "Nom en français", attribute.name(locale: "fr")
      assert_equal "Description en français", attribute.description(locale: "fr")
      assert_equal "Nombre en español", attribute.name(locale: "es")
      assert_equal "Descripción en español", attribute.description(locale: "es")
      assert_equal "Raw name", attribute.name(locale: "cs") # fall back to en
      assert_equal "Raw description", attribute.description(locale: "cs") # fall back to en
    end
  end
end