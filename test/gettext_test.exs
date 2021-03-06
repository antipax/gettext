defmodule GettextTest.Translator do
  use Gettext, otp_app: :test_application
end

defmodule GettextTest.TranslatorWithCustomPriv do
  use Gettext, otp_app: :test_application, priv: "translations"
end

defmodule GettextTest.TranslatorWithCustomPluralForms do
  defmodule Plural do
    @behaviour Gettext.Plural
    def nplurals("elv"), do: 2
    # Opposite of Italian (where 1 is singular, everything else is plural)
    def plural("it", 1), do: 1
    def plural("it", _), do: 0
  end

  use Gettext, otp_app: :test_application, plural_forms: Plural
end

defmodule GettextTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias GettextTest.Translator
  alias GettextTest.TranslatorWithCustomPriv
  alias GettextTest.TranslatorWithCustomPluralForms
  require Translator
  require TranslatorWithCustomPriv

  test "the default locale is \"en\"" do
    assert Gettext.get_locale(Translator) == "en"
  end

  test "get_locale/1 and put_locale/2: setting/getting the locale" do
    Gettext.put_locale(Translator, "pt_BR")
    assert Gettext.get_locale(Translator) == "pt_BR"
    assert Gettext.get_locale(TranslatorWithCustomPriv) == "en"
  end

  test "put_locale/2: only accepts binaries" do
    msg = "put_locale/2 only accepts binary locales, got: :en"
    assert_raise ArgumentError, msg, fn ->
      Gettext.put_locale(Translator, :en)
    end
  end

  test "__gettext__(:priv): returns the directory where the translations are stored" do
    assert Translator.__gettext__(:priv) == "priv/gettext"
    assert TranslatorWithCustomPriv.__gettext__(:priv) == "translations"
  end

  test "__gettext__(:otp_app): returns the otp app for the given backend" do
    assert Translator.__gettext__(:otp_app) == :test_application
    assert TranslatorWithCustomPriv.__gettext__(:otp_app) == :test_application
  end

  test "found translations return {:ok, translation}" do
    assert Translator.lgettext("it", "default", "Hello world", %{})
           == {:ok, "Ciao mondo"}

    assert Translator.lgettext("it", "errors", "Invalid email address", %{})
           == {:ok, "Indirizzo email non valido"}
  end

  test "non-found translations return the argument message" do
    # Unknown msgid.
    assert Translator.lgettext("it", "default", "nonexistent", %{})
           == {:default, "nonexistent"}

    # Unknown domain.
    assert Translator.lgettext("it", "unknown", "Hello world", %{})
           == {:default, "Hello world"}

    # Unknown locale.
    assert Translator.lgettext("pt_BR", "nonexistent", "Hello world", %{})
           == {:default, "Hello world"}
  end

  test "translations with empty msgstrs fallback to {:default, _}" do
    assert Translator.lgettext("it", "default", "Empty msgstr!", %{})
           == {:default, "Empty msgstr!"}
  end

  test "a custom 'priv' directory can be used to store translations" do
    assert TranslatorWithCustomPriv.lgettext("it", "default", "Hello world", %{})
           == {:ok, "Ciao mondo"}

    assert TranslatorWithCustomPriv.lgettext("it", "errors", "Invalid email address", %{})
           == {:ok, "Indirizzo email non valido"}
  end

  test "using a custom Gettext.Plural module" do
    alias TranslatorWithCustomPluralForms, as: T
    assert T.lngettext("it", "default", "One new email", "%{count} new emails", 1, %{}) ==
           {:ok, "1 nuove email"}
    assert T.lngettext("it", "default", "One new email", "%{count} new emails", 2, %{}) ==
           {:ok, "Una nuova email"}
  end

  test "translations can be pluralized" do
    import Translator, only: [lngettext: 6]

    t = lngettext("it", "errors", "There was an error", "There were %{count} errors", 1, %{})
    assert t == {:ok, "C'è stato un errore"}

    t = lngettext("it", "errors", "There was an error", "There were %{count} errors", 3, %{})
    assert t == {:ok, "Ci sono stati 3 errori"}
  end

  test "by default, non-found pluralized translation behave like regular translation" do
    assert Translator.lngettext("it", "not a domain", "foo", "foos", 1, %{})
           == {:default, "foo"}
    assert Translator.lngettext("it", "not a domain", "foo", "foos", 10, %{})
           == {:default, "foos"}
  end

  test "plural translations with empty msgstrs fallback to {:default, _}" do
    msgid        = "Not even one msgstr"
    msgid_plural = "Not even %{count} msgstrs"

    assert Translator.lngettext("it", "default", msgid, msgid_plural, 1, %{})
           == {:default, "Not even one msgstr"}
    assert Translator.lngettext("it", "default", msgid, msgid_plural, 2, %{})
           == {:default, "Not even 2 msgstrs"}
  end

  test "interpolation is supported by lgettext" do
    assert Translator.lgettext("it", "interpolations", "Hello %{name}", %{name: "Jane"})
           == {:ok, "Ciao Jane"}

    msgid = "My name is %{name} and I'm %{age}"
    assert Translator.lgettext("it", "interpolations", msgid, %{name: "Meg", age: 33})
           == {:ok, "Mi chiamo Meg e ho 33 anni"}

    # A map of bindings is supported as well.
    assert Translator.lgettext("it", "interpolations", "Hello %{name}", %{name: "Jane"})
           == {:ok, "Ciao Jane"}
  end

  test "interpolation is supported by lngettext" do
    msgid        = "There was an error"
    msgid_plural = "There were %{count} errors"
    assert Translator.lngettext("it", "errors", msgid, msgid_plural, 1, %{})
           == {:ok, "C'è stato un errore"}
    assert Translator.lngettext("it", "errors", msgid, msgid_plural, 4, %{})
           == {:ok, "Ci sono stati 4 errori"}

    msgid        = "You have one message, %{name}"
    msgid_plural = "You have %{count} messages, %{name}"
    assert Translator.lngettext("it", "interpolations", msgid, msgid_plural, 1, %{name: "Jane"})
           == {:ok, "Hai un messaggio, Jane"}
    assert Translator.lngettext("it", "interpolations", msgid, msgid_plural, 0, %{name: "Jane"})
           == {:ok, "Hai 0 messaggi, Jane"}
  end

  test "strings are concatenated before generating function clauses" do
    msgid = "Concatenated and long string"
    assert Translator.lgettext("it", "default", msgid, %{})
           == {:ok, "Stringa lunga e concatenata"}

    msgid        = "A friend"
    msgid_plural = "%{count} friends"
    assert Translator.lngettext("it", "default", msgid, msgid_plural, 1, %{})
           == {:ok, "Un amico"}
  end

  test "lgettext/4: error when keys are missing in an interpolation" do
    msgid = "My name is %{name} and I'm %{age}"
    assert Translator.lgettext("it", "interpolations", msgid, %{name: "José"})
           == {:error, "missing interpolation keys: age"}
  end

  test "lgettext/4: interpolation works when a translation is missing" do
    msgid = "Hello %{name}, missing translation!"
    assert Translator.lgettext("pl", "foo", msgid, %{name: "Samantha"})
           == {:default, "Hello Samantha, missing translation!"}

    msgid = "Hello world!"
    assert Translator.lgettext("pl", "foo", msgid, %{})
           == {:default, "Hello world!"}

    msgid = "Hello %{name}"
    assert Translator.lgettext("pl", "foo", msgid, %{})
           == {:error, "missing interpolation keys: name"}
  end

  test "lngettext/6: error when keys are missing in an interpolation" do
    msgid =  "You have one message, %{name}"
    msgid_plural = "You have %{count} messages, %{name}"

    assert Translator.lngettext("it", "interpolations", msgid, msgid_plural, 1, %{})
           == {:error, "missing interpolation keys: name"}

    assert Translator.lngettext("it", "interpolations", msgid, msgid_plural, 6, %{})
           == {:error, "missing interpolation keys: name"}
  end

  test "lngettext/6: interpolation works when a translation is missing" do
    msgid        = "One error"
    msgid_plural = "%{count} errors"
    assert Translator.lngettext("pl", "foo", msgid, msgid_plural, 1, %{})
           == {:default, "One error"}
    assert Translator.lngettext("pl", "foo", msgid, msgid_plural, 9, %{})
           == {:default, "9 errors"}
  end

  test "dgettext/3: binary msgid at compile-time" do
    Gettext.put_locale Translator, "it"

    assert Translator.dgettext("errors", "Invalid email address")
           == "Indirizzo email non valido"
    keys = %{name: "Jim"}
    assert Translator.dgettext("interpolations", "Hello %{name}", keys)
           == "Ciao Jim"

    msg = "missing interpolation keys: name"
    assert_raise Gettext.Error, msg, fn ->
      Translator.dgettext("interpolations", "Hello %{name}")
    end
  end

  # Macros.

  @gettext_msgid "Hello world"

  test "gettext/2: binary-ish msgid at compile-time" do
    Gettext.put_locale Translator, "it"
    assert Translator.gettext("Hello world") == "Ciao mondo"
    assert Translator.gettext(@gettext_msgid) == "Ciao mondo"
    assert Translator.gettext(~s(Hello world)) == "Ciao mondo"
  end

  test "dgettext/3 and dngettext/2: non-binary things at compile-time" do
    code = quote do
      require Translator
      msgid = "Invalid email address"
      Translator.dgettext("errors", msgid)
    end
    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    assert ArgumentError.message(error) =~ "*gettext macros expect translation keys"
    assert ArgumentError.message(error) =~ "Gettext.gettext(GettextTest.Translator, string)"

    code = quote do
      require Translator
      msgid_plural = ~s(foo #{1 + 1} bar)
      Translator.dngettext("default", "foo", msgid_plural, 1)
    end
    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    assert ArgumentError.message(error) =~ "*gettext macros expect translation keys"
    assert ArgumentError.message(error) =~ "Gettext.gettext(GettextTest.Translator, string)"

    code = quote do
      require Translator
      domain = "dynamic_domain"
      Translator.dgettext(domain, "hello")
    end
    error = assert_raise ArgumentError, fn -> Code.eval_quoted(code) end
    assert ArgumentError.message(error) =~ "*gettext macros expect translation keys"
  end

  test "dngettext/5" do
    Gettext.put_locale Translator, "it"
    assert Translator.dngettext(
      "interpolations",
      "You have one message, %{name}",
      "You have %{count} messages, %{name}",
      1,
      %{name: "James"}
    ) == "Hai un messaggio, James"
    assert Translator.dngettext(
      "interpolations",
      "You have one message, %{name}",
      "You have %{count} messages, %{name}",
      2,
      %{name: "James"}
    ) == "Hai 2 messaggi, James"
  end

  @ngettext_msgid "One new email"
  @ngettext_msgid_plural "%{count} new emails"

  test "ngettext/4" do
    Gettext.put_locale Translator, "it"
    assert Translator.ngettext("One new email", "%{count} new emails", 1)
           == "Una nuova email"
    assert Translator.ngettext("One new email", "%{count} new emails", 2)
           == "2 nuove email"

    assert Translator.ngettext(@ngettext_msgid, @ngettext_msgid_plural, 1)
           == "Una nuova email"
    assert Translator.ngettext(@ngettext_msgid, @ngettext_msgid_plural, 2)
           == "2 nuove email"
  end

  test "the d?n?gettext macros support a kw list for interpolation" do
    Gettext.put_locale Translator, "it"
    assert Translator.gettext("%{msg}", msg: "foo") == "foo"
  end


  # Actual Gettext functions (not the ones generated in the modules that `use
  # Gettext`).

  test "dgettext/4" do
    Gettext.put_locale Translator, "it"

    msgid = "Invalid email address"
    assert Gettext.dgettext(Translator, "errors", msgid)
           == "Indirizzo email non valido"

    assert Gettext.dgettext(Translator, "foo", "Foo") == "Foo"

    msg = "missing interpolation keys: name"
    assert_raise Gettext.Error, msg, fn ->
      Gettext.dgettext(Translator, "interpolations", "Hello %{name}", %{})
    end
  end

  test "gettext/3" do
    Gettext.put_locale Translator, "it"
    assert Gettext.gettext(Translator, "Hello world") == "Ciao mondo"
    assert Gettext.gettext(Translator, "Nonexistent") == "Nonexistent"
  end

  test "dngettext/6" do
    Gettext.put_locale Translator, "it"
    msgid        = "You have one message, %{name}"
    msgid_plural = "You have %{count} messages, %{name}"
    assert Gettext.dngettext(Translator, "interpolations", msgid, msgid_plural, 1, %{name: "Meg"})
           == "Hai un messaggio, Meg"
    assert Gettext.dngettext(Translator, "interpolations", msgid, msgid_plural, 5, %{name: "Meg"})
           == "Hai 5 messaggi, Meg"
  end

  test "ngettext/5" do
    Gettext.put_locale Translator, "it"
    msgid        = "One cake, %{name}"
    msgid_plural = "%{count} cakes, %{name}"
    assert Gettext.ngettext(Translator, msgid, msgid_plural, 1, %{name: "Meg"})
           == "One cake, Meg"
    assert Gettext.ngettext(Translator, msgid, msgid_plural, 5, %{name: "Meg"})
           == "5 cakes, Meg"
  end

  test "the d?n?gettext functions support kw list for interpolations" do
    Gettext.put_locale Translator, "it"
    assert Gettext.gettext(Translator, "Hello %{name}", name: "José") == "Hello José"
  end

  test "with_locale/3 runs a function with a given locale and returns the returned value" do
    Gettext.put_locale Translator, "fr"
    assert Gettext.gettext(Translator, "Hello world") == "Hello world" # no 'fr' translation
    res = Gettext.with_locale Translator, "it", fn ->
      assert Gettext.gettext(Translator, "Hello world") == "Ciao mondo"
      :foo
    end

    assert res == :foo
  end

  test "with_locale/3 resets the locale even if the given function raises" do
    Gettext.put_locale Translator, "fr"

    assert_raise RuntimeError, fn ->
      Gettext.with_locale Translator, "it", fn -> raise "foo" end
    end
    assert Gettext.get_locale(Translator) == "fr"

    catch_throw(Gettext.with_locale Translator, "it", fn -> throw :foo end)
    assert Gettext.get_locale(Translator) == "fr"
  end

  test "with_locale/3: doesn't raise if no locale was set (defaulting to 'en')" do
    Process.delete(Translator)
    Gettext.with_locale Translator, "it", fn ->
      assert Gettext.gettext(Translator, "Hello world") == "Ciao mondo"
    end
  end

  test "known_locales/1: returns all the locales for which a backend has PO files" do
    assert Gettext.known_locales(Translator) == ["it"]
    assert Gettext.known_locales(TranslatorWithCustomPriv) == ["it"]
  end

  test "a warning is issued in l(n)gettext when the domain contains slashes" do
    io = capture_io :stderr, fn ->
      assert Translator.dgettext("sub/dir/domain", "hello") == "hello"
    end
    assert io =~ ~s(warning: slashes in domains are not supported: "sub/dir/domain")
  end
end
