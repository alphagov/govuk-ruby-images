#!/usr/bin/env ruby

def colorised_govuk_environment
  govuk_environment = ENV.fetch("GOVUK_ENVIRONMENT", "unknown env")
  case govuk_environment
  when "integration", "staging"
    IRB::Color.colorize(govuk_environment, [:YELLOW])
  when "production"
    IRB::Color.colorize(govuk_environment, [:RED])
  else
    IRB::Color.colorize(govuk_environment, [:BLUE])
  end
end

app = ENV.fetch("GOVUK_APP_NAME", "unknown app")
prompt = "#{app} (#{colorised_govuk_environment})"

IRB.conf[:PROMPT][:GOVUK] = {
  PROMPT_I: "#{prompt}>> ",
  PROMPT_N: "#{prompt}> ",
  PROMPT_S: "#{prompt}* ",
  PROMPT_C: "#{prompt}? ",
  RETURN: " => %s\n",
}

IRB.conf[:PROMPT_MODE] = :GOVUK
