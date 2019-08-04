class RobotsTxtsController < ApplicationController
  DISALLOW_ROBOTS = %q{User-agent: *
Disallow: /
  }
  def show
    render content_type: "text/plain", plain: DISALLOW_ROBOTS
  end
end
