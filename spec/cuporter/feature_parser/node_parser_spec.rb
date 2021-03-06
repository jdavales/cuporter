require 'spec_helper'

module Cuporter
  describe NodeParser do
    let(:file)  {"file.feature"}
    let(:doc)  { Cuporter::Document.new_xml}

    context "#parse_feature" do
      context "Unfiltered: one scenario" do
        it "returns a feature name and scenario name" do
          content = <<EOF
Feature: just one scenario

  Scenario: the scenario in question
    Given foo
    When bar
    Then wow
    And gee
EOF
          File.should_receive(:read).with(file).and_return(content)
          feature = NodeParser.new(file, doc, Filter.new).parse_feature
          feature.should be_a Cuporter::Node::NodeBase
          feature.file_path.should == file
          feature.cuke_name.should == "Feature: just one scenario"
          feature.should have_children
          feature.children.first.cuke_name.should == "Scenario: the scenario in question"
        end
      end

      context "Filtered: tag on feature" do
        let(:content) { <<EOF
   @wip
Feature: two scenarios

  Scenario: the scenario in question
    Given foo
    When bar
    Then wow
    And gee

  Scenario: the other
    Given foo
    When bar
    Then wow
    And gee
EOF
            }
        context "none filter" do
          it "returns an empty feature" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:none => :@wip)).parse_feature
            feature.cuke_name.should == "Feature: two scenarios"
            feature.should_not have_children
          end
        end

        context "any filter" do
          it "returns the feature with both scenarios" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:any => :@wip)).parse_feature
            feature.cuke_name.should == "Feature: two scenarios"
            feature.cuke_names.should == ["Scenario: the scenario in question", "Scenario: the other"]
          end
        end

      end
      context "Filtered: tag on one scenario" do
        let(:content) { <<EOF
Feature: two scenarios

  Scenario: the scenario in question
    Given foo
    When bar
    Then wow
    And gee

  @wip
  Scenario: the other
    Given foo
    When bar
    Then wow
    And gee
EOF
            }
        context "none filter" do
          it "returns the feature with one scenario" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:none => :@wip)).parse_feature
            feature.cuke_name.should == "Feature: two scenarios"
            feature.cuke_names.should == ["Scenario: the scenario in question"]
          end
        end

        context "any filter" do
          it "returns the feature with the other scenario" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:any => :@wip)).parse_feature
            feature.cuke_name.should == "Feature: two scenarios"
            feature.cuke_names.should == ["Scenario: the other"]
          end
        end

      end

      context "Filtered: tag on outline, none on scenarios" do
        let(:content) { <<EOF
Feature: two scenarios one outline

  Scenario: the scenario in question
    Given foo
    When bar
    Then wow
    And gee

  Scenario: the other
    Given foo
    When bar
    Then wow
    And gee

  @wip
  Scenario Outline: outline
    Given <foo>
    When  "<bar>"
    The   "<unbar>"

    Examples: tests
      |foo | bar | unbar |
      | a  | b   | c     |
      | d  | e   | f     |

EOF
        }
        context "none filter" do
          it "returns a feature with two scenarios" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:none => :@wip)).parse_feature
            feature.cuke_name.should == "Feature: two scenarios one outline"
            feature.cuke_names.should == ["Scenario: the scenario in question", "Scenario: the other"]
          end
        end

        context "any filter" do
          it "returns the feature with the outline" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:any => :@wip)).parse_feature
            feature.cuke_name.should == "Feature: two scenarios one outline"
            feature.cuke_names.should == ["Scenario Outline: outline"]
          end
        end

      end

      context "Filtered: tag on one scenario, no tag on outline" do
        let(:content) { <<EOF
Feature: two scenarios one outline

  Scenario: the scenario in question
    Given foo
    When bar
    Then wow
    And gee

  @wip
  Scenario: the other
    Given foo
    When bar
    Then wow
    And gee

  Scenario Outline: outline
    Given <foo>
    When  "<bar>"
    The   "<unbar>"

    Examples: tests
      |foo | bar | unbar |
      | a  | b   | c     |
      | d  | e   | f     |
EOF
 }
        context "none filter" do
          it "returns the feature with a scenario and a scenario outline" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:none => :@wip)).parse_feature
            feature.cuke_name.should == "Feature: two scenarios one outline"
            feature.cuke_names.should == ["Scenario: the scenario in question", "Scenario Outline: outline"]
            feature.at(:scenario_outline).cuke_names.should == ["Examples: tests"]
            feature.at(:scenario_outline).at(:examples).children.size.should == 3
          end
        end

        context "any filter" do
          it "returns the feature with one scenario" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:any => :@wip)).parse_feature
            feature.cuke_name.should == "Feature: two scenarios one outline"
            feature.cuke_names.should == ["Scenario: the other"]
          end
        end

      end

      context "Filtered: tags on feature, 1 of 2 scenarios and scenario outline" do
        let(:content) { <<EOF
@feature
Feature: two scenarios one outline

  @scenario
  Scenario: the scenario in question
    Given foo
    When bar
    Then wow
    And gee

  Scenario: the other
    Given foo
    When bar
    Then wow
    And gee

  @outline
  Scenario Outline: outline
    Given <foo>
    When  "<bar>"
    The   "<unbar>"

    Examples: tests
      |foo | bar | unbar |
      | a  | b   | c     |
      | d  | e   | f     |
EOF
 }
        context "include scenario and outline tags, exclude non-matching tag" do
          it "returns the feature and the untagged scenario" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:any => %w[@scenario @outline], :none => :@jack)).parse_feature
            feature.cuke_name.should == "Feature: two scenarios one outline"
            feature.cuke_names.should == ["Scenario: the scenario in question", "Scenario Outline: outline"]
          end
        end

        context "include feature tag, exclude scenario and outline tags" do
          it "returns the feature and the untagged scenario" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:any => :@feature, :none => %w[@scenario @outline])).parse_feature
            feature.cuke_name.should == "Feature: two scenarios one outline"
            feature.cuke_names.should == ["Scenario: the other"]
          end
        end
        context "exclude feature tags, include scenario and outline tags" do
          it "returns an empty feature" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:any => %w[@scenario @outline], :none => :@feature)).parse_feature
            feature.cuke_name.should == "Feature: two scenarios one outline"
            feature.should_not have_children
          end
        end

      
      end

      context "Filtered: tag on outline and one example set" do
        let(:content) { <<EOF
@feature
Feature: two scenarios one outline

  @scenario
  Scenario: the scenario in question
    Given foo
    When bar
    Then wow
    And gee

  @outline
  Scenario Outline: outline
    Given <foo>
    When  "<bar>"
    The   "<unbar>"

    @example_set
    Examples: we are tagged
      |foo | bar | unbar |
      | a  | b   | c     |
      | d  | e   | f     |

    Examples: other tests
      |foo | bar | unbar |
      | a  | b   | c     |
      | d  | e   | f     |
EOF
 }
        context "include outline tag AND example set tag" do
          it "returns the tagged example set" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:all => %w[@example_set @outline])).parse_feature
            feature.cuke_name.should == "Feature: two scenarios one outline"
            feature.cuke_names.should == ["Scenario Outline: outline"]
            feature.at(:scenario_outline).cuke_names.should == ["Examples: we are tagged"]
          end
        end

        context "include outline tag AND exclude example set tag" do
          it "returns the other example set" do
            File.should_receive(:read).with(file).and_return(content)
            feature = NodeParser.new(file, doc, Filter.new(:all => :@outline, :none => :@example_set )).parse_feature
            feature.cuke_name.should == "Feature: two scenarios one outline"
            feature.cuke_names.should == ["Scenario Outline: outline"]
            feature.at(:scenario_outline).cuke_names.should == ["Examples: other tests"]
          end
        end
      end
    end

  end
end

