# frozen_string_literal: true

class GymRoute < ApplicationRecord
  include AttachmentResizable

  has_one_attached :picture
  has_one_attached :thumbnail
  belongs_to :gym_sector, optional: true
  belongs_to :gym_grade_line, optional: true
  has_one :gym_space, through: :gym_sector
  has_one :gym, through: :gym_sector
  has_many :videos, as: :viewable

  delegate :feed_parent_id, to: :gym
  delegate :feed_parent_type, to: :gym
  delegate :feed_parent_object, to: :gym

  validates :opened_at, presence: true
  validates :gym_grade_line, presence: true, if: proc { |obj| obj.gym_sector.gym_grade.need_grade_line? }
  validates :climbing_type, inclusion: { in: Climb::GYM_LIST }
  validates :height, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :validate_sections

  validates :picture, blob: { content_type: :image }, allow_nil: true
  validates :thumbnail, blob: { content_type: :image }, allow_nil: true

  before_validation :format_route_section
  before_save :historize_grade_gap
  before_save :historize_sections_count

  scope :dismounted, -> { where.not(dismounted_at: nil) }
  scope :mounted, -> { where(dismounted_at: nil) }

  def gym_grade
    gym_grade_line&.gym_grade || gym_sector.gym_grade
  end

  def points_to_s
    return '' unless gym_grade.use_point_system || gym_grade.use_point_division_system

    ascents_count = self.ascents_count&.positive? ? self.ascents_count : 1
    points = self.points if gym_grade.use_point_system
    points = 1000 / ascents_count if gym_grade.use_point_division_system
    "#{points}pts"
  end

  def grade_to_s
    return '' unless gym_grade.use_grade_system

    if sections_count > 1
      sections_array = []
      sections.each do |section|
        sections_array << section['grade']
      end
      sections_array.join(', ')
    else
      min_grade_text
    end
  end

  def identification_to_s
    identifications = {
      hold_color: :hold,
      pan: :tag,
      tag_color: :tag_and_hold,
      grade: :hold
    }
    identifications[gym_grade.difficulty_system.to_sym]
  end

  def mounted?
    dismounted_at.blank?
  end

  def dismounted?
    dismounted_at.present?
  end

  def dismount!
    self.dismounted_at = Time.zone.now
    save
  end

  def mount!
    self.dismounted_at = nil
    save
  end

  def picture_large_url
    resize_attachment picture, '700x700'
  end

  def thumbnail_url
    resize_attachment picture, '300x300'
  end

  private

  def format_route_section
    new_sections = []
    single_pitch = sections.count == 1

    sections.each do |section|
      section_height = section['height'].present? ? Integer(section['height']) : nil
      new_sections << {
        climbing_type: single_pitch ? climbing_type : section['climbing_type'] || climbing_type,
        description: !single_pitch ? section['description'] : nil,
        grade: Grade.clean_grade(section['grade']),
        grade_value: Grade.to_value(section['grade']),
        height: single_pitch ? height : section_height,
        points: single_pitch ? points : section['points'],
        tags: section['tags']
      }
    end
    self.sections = new_sections
  end

  def historize_grade_gap
    max_grade_value = nil
    max_grade_text = nil
    min_grade_value = nil
    min_grade_text = nil

    sections.each do |section|
      next unless section['grade']

      max_grade_text = section['grade'] if max_grade_value.nil? || section['grade_value'] > max_grade_value
      max_grade_value = section['grade_value'] if max_grade_value.nil? || section['grade_value'] > max_grade_value

      min_grade_text = section['grade'] if min_grade_value.nil? || section['grade_value'] < min_grade_value
      min_grade_value = section['grade_value'] if min_grade_value.nil? || section['grade_value'] < min_grade_value
    end

    self.max_grade_text = max_grade_text
    self.min_grade_text = min_grade_text
    self.max_grade_value = max_grade_value
    self.min_grade_value = min_grade_value
  end

  def historize_sections_count
    self.sections_count =  sections.count
  end

  def validate_sections
    sections.each do |section|
      # valid types
      errors.add(:grade, I18n.t('activerecord.errors.messages.inclusion')) if section['grade'].present? && !Grade.valid?(section['grade'])

      # Valid numerics
      errors.add(:height, I18n.t('activerecord.errors.messages.greater_than')) if section['height'].present? && Integer(section['height']).negative?
    end
  end
end
