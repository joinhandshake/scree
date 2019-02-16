module JsTrigger
  def trigger(event)
    # Avoid JQuery dependency. A little bit of a dumb, hacky workaround.
    # Most built-ins have a same-named function (e.g. 'click'), so try
    # using that. Otherwise, assume it's custom.
    trigger_script = <<~JS_SCRIPT
      var elem = arguments[0];
      var name = arguments[1];

      if(elem[name] === undefined) {
        var event = new CustomEvent(name, {bubbles: true, cancelable: true});
        elem.dispatchEvent(event);
      } else {
        elem[name]();
      };
    JS_SCRIPT

    driver.execute_script(
      trigger_script,
      native,
      event.to_s
    )
  end
end

::Capybara::Selenium::Node.prepend JsTrigger
