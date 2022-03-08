# frozen_string_literal: true

class BaseRequestParams
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  validate :assocations_valid

  attr_accessor :ability, :by

  def self.association(association, klass, options = {})
    @@associations ||= {}
    @@associations[name] ||= {}
    options = { key: association, klass: klass, **options }
    if klass.is_a?(Class)
      options[:parent_klass] = self
      klass.attr_accessor :index if options.present? && options[:array]
    end
    @@associations[name][association] = options
  end

  def self.attributes(*attr_names)
    attr_names.each do |attr_name|
      attribute(attr_name)
    end
  end

  def initialize(*args)
    associations.each do |key, options|
      next unless associations[key][:klass].is_a?(Class)

      # rails fields_for would call this for nested data
      define_singleton_method("#{key}_attributes=") do |values|
        send("#{key}=", transform_association(values, options))
      end
    end

    super(*args)
  end

  def to_h
    attributes.with_indifferent_access
  end

  def parse_json(params)
    keys = json_params_to_permitted_keys(self.class)
    permitted = params.permit(*keys)
    assign_json_values(permitted, self)
    self
  end

  def assign_json_values(values, instance)
    values.each_key do |key|
      klass = instance.class
      association = lookup_association(klass, key)
      if association.present? && association[:array]
        instances = values[key].map do |value|
          nested_instance = association[:klass].new
          assign_json_values(value, nested_instance)
          nested_instance
        end
        instance.send("#{key}=", instances)
      elsif association.present? && !association[:array]
        nested_instance = association[:klass].new
        instance.send("#{key}=", nested_instance)
        assign_json_values(values[key], nested_instance)
      else
        instance.send("#{key}=", values[key])
      end
    end
  end

  def json_params_to_permitted_keys(klass)
    klass.attribute_names.map do |key|
      association = lookup_association(klass, key)
      if association.present?
        { key => json_params_to_permitted_keys(association[:klass]) }
      else
        key
      end
    end
  end

  def lookup_association(klass, key)
    @@associations ||= {}
    while klass != BaseRequestParams && !klass.nil?
      association = (@@associations[klass.name] || {})[key.to_sym]
      return association if association.present?

      klass = klass.superclass
    end
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/BlockLength
  def <<(params)
    keys = self.class.attribute_names.map do |key|
      type = self.class.attribute_types[key]
      association = associations[key.to_sym]
      if type.respond_to?(:permitted_values)
        { key => type.permitted_values }
      elsif association.present? && association[:klass].is_a?(Class)
        { "#{key}_attributes" => {} }
      elsif association.present? && association[:array] == true
        { key => [] }
      else
        key
      end
    end
    permitted = params.permit(*keys)
    permitted.each_key do |key|
      value = permitted[key]
      if associations.include?(key) && associations[key][:klass] == :check_box && associations[key][:array] == true
        send("#{key}=", value.filter(&:present?).compact.map(&:to_i))
      else
        send("#{key}=", value)
      end
    end
    associations.each_key do |key|
      if associations[key][:klass] == :get_check_box
        checkbox_value = []
        checkbox_value = params[key] if params[key].presence && params[key].is_a?(Array)
        params.each_key do |param_key|
          checkbox_key = param_key.match("#{key}__(.*)__")
          next unless checkbox_key.presence &&
                      checkbox_key.length.positive? &&
                      params[param_key].present? &&
                      params[param_key] == 'true'

          checkbox_value.push(checkbox_key[1])
        end
        send("#{key}=", checkbox_value)
      end
      next unless associations[key][:klass].is_a?(Class)

      attributes_key = "#{key}_attributes"
      send("#{attributes_key}=", permitted[attributes_key])
      associations[key][:klass].attribute_names.map do |sub_key|
        subclass = associations[key][:klass]
        subclass_associations = @@associations[subclass.name] || {}

        unless !subclass_associations[sub_key.to_sym].nil? && subclass_associations[sub_key.to_sym][:klass].is_a?(Class)
          next
        end

        attributes_sub_key = "#{sub_key}_attributes"
        permitted[attributes_key].each_key do |index|
          localized_properties = send(key)
          localized_properties[index.to_i].send("#{attributes_sub_key}=",
                                                permitted[attributes_key][index][attributes_sub_key])
        end

        subclass_associations[sub_key.to_sym][:klass].attribute_names.map do |nested_key|
          nested_class = associations[key][:klass]
          nested_class_associations = @@associations[nested_class.name] || {}

          if !nested_class_associations[nested_key.to_sym].nil? &&
             nested_class_associations[nested_key.to_sym][:klass].is_a?(Class)
            raise StandardError, 'nested nested association not supported yet'
          end
        end
      end
    end
    self
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/BlockLength

  def error?(key: nil)
    return errors.blank? if key.nil?

    errors.include?(key)
  end

  def nested_attributes?(key)
    associations[key].present? && associations[key][:klass].is_a?(Class)
  end

  def ordering
    "#{sort_by} #{order == 'desc' ? 'DESC' : 'ASC'}"
  end

  def next_page
    dup.tap do |new_param|
      new_param.offset = new_param.offset + new_param.limit
    end
  end

  def prev_page
    dup.tap do |new_param|
      new_param.offset = new_param.offset - new_param.limit
    end
  end

  def next_ordering(name)
    dup.tap do |new_param|
      if new_param.sort_by == name && new_param.order == 'asc'
        new_param.sort_by = name
        new_param.order = 'desc'
      elsif new_param.sort_by == name
        new_param.sort_by = 'id'
        new_param.order = 'asc'
      else
        new_param.sort_by = name
        new_param.order = 'asc'
      end

      new_param.offset = 0
    end
  end

  def all_errors
    errs = []
    each_error { errs << _1 }
    errs
  end

  def each_error(&block)
    errors.each(&block)

    associations.each do |key, options|
      value = send(key)
      next if value.nil?

      case options
      in { klass: Class, array: true }
        value.each { |item| item.errors.each(&block) }
      in { klass: Class }
        value.errors.each(&block)
      else
        next
      end
    end
  end

  protected

  def new_instance_of_association(key, *args)
    options = associations[key]
    instance = options[:klass].new(*args)
    if options[:parent_klass].is_a?(Class)
      instance.define_singleton_method('parent_class') { options[:parent_klass] }
      instance.define_singleton_method('nested_key') { "#{key}_attributes" }
    end
    instance
  end

  private

  def associations
    return {} unless defined?(@@associations)

    (@@associations[self.class.name] || {}).with_indifferent_access
  end

  def assocations_valid
    associations.each do |key, options|
      value = send(key)
      next if value.nil?

      case options
      in { klass: Class, array: true }
        value.each do |item|
          item.validate
          errors.add(key.to_sym, :invalid) if item.invalid?
        end
      in { klass: Class }
        value.validate
        errors.add(key.to_sym, :invalid) if value.invalid?
      else
        next
      end
    end
  end

  def transform_association(values, options)
    case [values, options]
    in [ActionController::Parameters, _]
      transform_association(values.to_h, options)
    in [Hash, { array: true }]
      values
        .to_a
        .inject([]) { |acc, v| acc.tap { acc[v[0].to_s.to_i] = { **v[1], index: v[0].to_i } } }
        .compact
        .map { |v| new_instance_of_association(options[:key], v) }
    in [_, { array: true }]
      []
    else
      raise StandardError, "association with 'array: false' not supported yet"
    end
  end
end
