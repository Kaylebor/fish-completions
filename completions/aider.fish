# Fish completion for aider
# Generated based on aider --help output and discussion
# User: Ender Veiga Bueno (A Coruña, Spain)
# Date: 2025-04-04 (Cleaned caching function)

# --- Helper Functions ---

# Helper function to check if any option precedes the current cursor position
# Prevents suggesting positional arguments (files) right after an option expecting its own argument.
function __fish_aider_no_options_present
    set -l cmd (commandline -opc)
    set -e cmd[1] # remove the command itself
    for i in $cmd
        if string match -q -- '-*' $i
            # Check if it's the last token and requires an argument
            if test $i = $cmd[(count $cmd)]
                # See if the option is known to require an argument for completion purposes
                complete -C "aider $i"
                if test $status -ne 0 # If the option is known and needs an arg
                    return 1 # Option needs arg, don't complete files now
                end
            else # Option isn't the last token
                return 1 # An option is present somewhere before, don't complete files now
            end
        end
    end
    return 0 # No options found before the cursor, safe to complete files
end

# Helper function to find available editors and add wait flags for known GUI/non-blocking ones
function __fish_aider_complete_editors_with_flags
    # List of common editors to check (helix for CachyOS/Linux)
    set -l common_editors code cursor zed subl kate emacsclient helix nvim vim vi emacs nano micro
    set -l available_editors

    for editor in $common_editors
        if command -v --quiet $editor
            set -l editor_to_add $editor
            switch $editor
                case code cursor subl zed
                    set editor_to_add "$editor --wait"
                case kate
                    set editor_to_add "$editor --block"
                case emacsclient
                    set editor_to_add "$editor -t"
            end
            set -a available_editors $editor_to_add
        end
    end

    set -l editor_base_cmd ""
    if test -n "$EDITOR"
        set editor_base_cmd (string split -n -m 1 ' ' -- $EDITOR)[1]
        if command -v --quiet $editor_base_cmd
            set -l found 0
            for item in $available_editors
                if string match -q -- "$editor_base_cmd*" $item
                    set found 1
                    break
                end
            end
            if test $found -eq 0
                set -a available_editors $editor_base_cmd
            end
        end
    end

    if test -n "$VISUAL"
        set -l visual_cmd (string split -n -m 1 ' ' -- $VISUAL)[1]
        if command -v --quiet $visual_cmd
            set -l found 0
            for item in $available_editors
                if string match -q -- "$visual_cmd*" $item
                    set found 1
                    break
                end
            end
            if test $found -eq 0
                if test "$visual_cmd" != "$editor_base_cmd"
                    set -a available_editors $visual_cmd
                end
            end
        end
    end

    for editor in $available_editors
        echo $editor
    end
end

# Helper function for provider prefixes with descriptions
function __fish_aider_complete_provider_prefixes_with_desc
    # Use echo -e to interpret the tab (\t) character
    echo -e "ai21\tAI21 Labs Models (Jamba, Jurassic)"
    echo -e "amazon\tAmazon Titan Models"
    echo -e "anthropic\tAnthropic Models (Claude)"
    echo -e "anyscale\tAnyscale Endpoints (Mistral, Mixtral)"
    echo -e "azure\tAzure OpenAI Models (gpt-*)"
    echo -e "azure_ai\tAzure AI Models (Llama, Phi)"
    echo -e "bedrock\tAWS Bedrock Models (various)"
    echo -e "bedrock_converse\tAWS Bedrock Converse API Models"
    echo -e "cerebras\tCerebras Models"
    echo -e "cloudflare\tCloudflare Workers AI"
    echo -e "cohere\tCohere Models (Command)"
    echo -e "deepinfra\tDeepInfra Models"
    echo -e "friendliai\tFriendliAI Models"
    echo -e "gemini\tGoogle Gemini Models (via AI Studio)"
    echo -e "groq\tGroqCloud Models (Llama)"
    echo -e "meta\tMeta Models (Llama, via various providers)"
    echo -e "mistral\tMistral AI Models (via various providers)"
    echo -e "ollama\tLocally served Ollama models"
    echo -e "openai\tOpenAI Models (GPT-*, ft:*)"
    echo -e "openrouter\tOpenRouter Models (various)"
    echo -e "perplexity\tPerplexity AI Models (Llama Sonar)"
    echo -e "replicate\tReplicate Models"
    echo -e "sambanova\tSambaNova Models"
    echo -e "snowflake\tSnowflake Arctic & Llama Models"
    echo -e "together\tTogether AI Models"
    echo -e "vertex_ai\tGoogle Vertex AI Models (Gemini, etc.)"
end

# Helper function to get model list, cached daily, with trailing tab
# Assumes models might be on stderr, redirects before processing
function __fish_aider_get_cached_models
    set -l cache_dir ~/.cache/fish
    set -l cache_file $cache_dir/aider_models.list
    set -l max_age 86400
    set -l regenerate 0

    # --- Cache Check Logic ---
    if test -e $cache_file
        set -l mtime 0
        if command -v gstat >/dev/null
            set mtime (gstat -c %Y $cache_file 2>/dev/null)
        else
            set mtime (stat -f %m $cache_file 2>/dev/null)
            if test $status -ne 0
                set mtime (stat -c %Y $cache_file 2>/dev/null)
            end
        end
        if test "$mtime" -gt 0
            set -l now (date +%s)
            set -l age (math $now - $mtime 2>/dev/null)
            if test $status -eq 0; and test "$age" -ge "$max_age"
                set regenerate 1
            end
            if test $status -ne 0
                set regenerate 1
            end # Error getting age
        else
            set regenerate 1
        end # Error getting mtime
    else
        set regenerate 1
    end # File missing
    # --- End Cache Check ---

    # Regenerate if needed
    if test $regenerate -eq 1
        mkdir -p $cache_dir
        if not command -v aider >/dev/null
            if test -e $cache_file
                cat $cache_file | awk 'NR > 2'
            end # Filter stale cache too
            return 1
        end

        # Keep track of stale cache content in case generation fails
        set -l stale_cache_content ""
        if test -e $cache_file
            set stale_cache_content (cat $cache_file)
        end

        # Generate processed list: Redirect stderr to stdout (2>&1) BEFORE awk
        set -l processed_list (aider --list-models '.' 2>&1 | awk 'NR > 2 { sub(/^- */, ""); print $0 "\t" }')
        set -l pipe_status $pipestatus # Capture status immediately

        # Check pipeline succeeded AND produced output
        if test (count $pipe_status) -eq 2; and test $pipe_status[1] -eq 0; and test $pipe_status[2] -eq 0; and test (count $processed_list) -gt 0
            # Success: Write the PROCESSED list to cache
            printf '%s\n' $processed_list >$cache_file
            # Check write status
            if test $status -ne 0
                rm -f $cache_file # Cleanup failed write
                # Output the list we generated for this completion run anyway
                printf '%s\n' $processed_list
                return 1
            else
                # Write SUCCESSFUL, output the list for this completion run
                printf '%s\n' $processed_list
                return 0
            end
        else
            # Generation FAILED. Output nothing useful now, maybe stale cache.
            if test -n "$stale_cache_content" # Check if stale content was captured
                echo "$stale_cache_content" | awk 'NR > 2' # Filter stale cache just in case
            end
            return 1
        end
    else
        # Cache HIT and VALID: Output cache content DIRECTLY. NO PROCESSING.
        cat $cache_file
        return 0
    end
end

# --- Main Options ---
complete -c aider -s h -l help -d 'Show this help message and exit' -f

# --- File Argument ---
complete -c aider -n __fish_aider_no_options_present -a '(__fish_complete_path)' -d 'File to edit'

# --- Model Options ---
complete -c aider -l model -r -f -a "(__fish_aider_get_cached_models)" -d 'Specify the model to use for the main chat [env var: AIDER_MODEL]'
complete -c aider -l weak-model -r -f -a "(__fish_aider_get_cached_models)" -d 'Specify model for commits and summarization [env var: AIDER_WEAK_MODEL]'
complete -c aider -l editor-model -r -f -a "(__fish_aider_get_cached_models)" -d 'Specify model for editor tasks [env var: AIDER_EDITOR_MODEL]'
complete -c aider -l list-models -r -f -a "(__fish_aider_complete_provider_prefixes_with_desc)" -d 'Search models matching prefix/name (e.g., openai, claude) [env var: AIDER_LIST_MODELS]'
complete -c aider -l models -r -f -a "(__fish_aider_complete_provider_prefixes_with_desc)" -d 'Alias for --list-models (search by prefix/name) [env var: AIDER_LIST_MODELS]'

# --- API Keys and settings ---
complete -c aider -l openai-api-key -r -f -d 'Specify the OpenAI API key [env var: AIDER_OPENAI_API_KEY]'
complete -c aider -l anthropic-api-key -r -f -d 'Specify the Anthropic API key [env var: AIDER_ANTHROPIC_API_KEY]'
complete -c aider -l openai-api-base -r -f -d 'Specify the api base url [env var: AIDER_OPENAI_API_BASE]'
complete -c aider -l openai-api-type -r -f -d '(deprecated) [env var: AIDER_OPENAI_API_TYPE]'
complete -c aider -l openai-api-version -r -f -d '(deprecated) [env var: AIDER_OPENAI_API_VERSION]'
complete -c aider -l openai-api-deployment-id -r -f -d '(deprecated) [env var: AIDER_OPENAI_API_DEPLOYMENT_ID]'
complete -c aider -l openai-organization-id -r -f -d '(deprecated) [env var: AIDER_OPENAI_ORGANIZATION_ID]'
complete -c aider -l set-env -r -f -d 'Set environment variable (VAR=value) [env var: AIDER_SET_ENV]' # No custom completion for VAR
complete -c aider -l api-key -r -f -a "(string split ' ' ai21 amazon anthropic anyscale azure azure_ai bedrock bedrock_converse cerebras cloudflare cohere deepinfra friendliai gemini groq meta mistral ollama openai openrouter perplexity replicate sambanova snowflake together vertex_ai)" -d 'Set API key (PROVIDER=KEY) for a provider [env var: AIDER_API_KEY]'

# --- Model settings (Continued) ---
complete -c aider -l model-settings-file -r -d 'Specify a file with aider model settings [env var: AIDER_MODEL_SETTINGS_FILE]' # File path ok
complete -c aider -l model-metadata-file -r -d 'Specify a file with context window and costs [env var: AIDER_MODEL_METADATA_FILE]' # File path ok
complete -c aider -l alias -r -f -d 'Add a model alias (ALIAS:MODEL) [env var: AIDER_ALIAS]'
complete -c aider -l reasoning-effort -r -f -d 'Set the reasoning_effort API parameter [env var: AIDER_REASONING_EFFORT]'
complete -c aider -l thinking-tokens -r -f -d 'Set the thinking token budget [env var: AIDER_THINKING_TOKENS]'
complete -c aider -l verify-ssl -f -d 'Verify the SSL cert (default: True) [env var: AIDER_VERIFY_SSL]'
complete -c aider -l no-verify-ssl -f -d 'Do not verify the SSL cert [env var: AIDER_VERIFY_SSL=False]'
complete -c aider -l timeout -r -f -d 'Timeout in seconds for API calls [env var: AIDER_TIMEOUT]'
complete -c aider -l edit-format -r -f -a "(string split ' ' whole diff search-replace udiff auto tool-xml)" -d 'Specify edit format (whole, diff, etc) [env var: AIDER_EDIT_FORMAT]'
complete -c aider -l chat-mode -r -f -a "(string split ' ' whole diff search-replace udiff auto tool-xml)" -d 'Alias for --edit-format [env var: AIDER_EDIT_FORMAT]'
complete -c aider -l architect -f -d 'Use architect edit format [env var: AIDER_ARCHITECT]'
complete -c aider -l auto-accept-architect -f -d 'Enable auto acceptance of architect changes (default: True) [env var: AIDER_AUTO_ACCEPT_ARCHITECT]'
complete -c aider -l no-auto-accept-architect -f -d 'Disable auto acceptance of architect changes [env var: AIDER_AUTO_ACCEPT_ARCHITECT=False]'
complete -c aider -l editor-edit-format -r -f -a "(string split ' ' whole diff search-replace udiff auto tool-xml)" -d 'Specify edit format for editor model [env var: AIDER_EDITOR_EDIT_FORMAT]'
complete -c aider -l show-model-warnings -f -d 'Only work with models with meta-data (default: True) [env var: AIDER_SHOW_MODEL_WARNINGS]'
complete -c aider -l no-show-model-warnings -f -d 'Allow models without meta-data [env var: AIDER_SHOW_MODEL_WARNINGS=False]'
complete -c aider -l check-model-accepts-settings -f -d 'Check if model accepts settings (default: True) [env var: AIDER_CHECK_MODEL_ACCEPTS_SETTINGS]'
complete -c aider -l no-check-model-accepts-settings -f -d 'Do not check if model accepts settings [env var: AIDER_CHECK_MODEL_ACCEPTS_SETTINGS=False]'
complete -c aider -l max-chat-history-tokens -r -f -d 'Soft limit on tokens for chat history [env var: AIDER_MAX_CHAT_HISTORY_TOKENS]'

# --- Cache settings ---
complete -c aider -l cache-prompts -f -d 'Enable caching of prompts (default: False) [env var: AIDER_CACHE_PROMPTS]'
complete -c aider -l no-cache-prompts -f -d 'Disable caching of prompts [env var: AIDER_CACHE_PROMPTS=False]'
complete -c aider -l cache-keepalive-pings -r -f -d 'Number of keepalive pings for cache (default: 0) [env var: AIDER_CACHE_KEEPALIVE_PINGS]'

# --- Repomap settings ---
complete -c aider -l map-tokens -r -f -d 'Suggested tokens for repo map (0 to disable) [env var: AIDER_MAP_TOKENS]'
complete -c aider -l map-refresh -r -f -a "(string split ' ' auto always files manual)" -d 'Control repo map refresh frequency (default: auto) [env var: AIDER_MAP_REFRESH]'
complete -c aider -l map-multiplier-no-files -r -f -d 'Multiplier for map tokens when no files specified (default: 2) [env var: AIDER_MAP_MULTIPLIER_NO_FILES]'

# --- History Files ---
complete -c aider -l input-history-file -r -d 'Specify chat input history file [env var: AIDER_INPUT_HISTORY_FILE]' # File path ok
complete -c aider -l chat-history-file -r -d 'Specify chat history file [env var: AIDER_CHAT_HISTORY_FILE]' # File path ok
complete -c aider -l restore-chat-history -f -d 'Restore previous chat history (default: False) [env var: AIDER_RESTORE_CHAT_HISTORY]'
complete -c aider -l no-restore-chat-history -f -d 'Do not restore previous chat history [env var: AIDER_RESTORE_CHAT_HISTORY=False]'
complete -c aider -l llm-history-file -r -d 'Log LLM conversation to this file [env var: AIDER_LLM_HISTORY_FILE]' # File path ok

# --- Output settings ---
complete -c aider -l dark-mode -f -d 'Use colors for dark terminal (default: False) [env var: AIDER_DARK_MODE]'
complete -c aider -l light-mode -f -d 'Use colors for light terminal (default: False) [env var: AIDER_LIGHT_MODE]'
complete -c aider -l pretty -f -d 'Enable pretty, colorized output (default: True) [env var: AIDER_PRETTY]'
complete -c aider -l no-pretty -f -d 'Disable pretty, colorized output [env var: AIDER_PRETTY=False]'
complete -c aider -l stream -f -d 'Enable streaming responses (default: True) [env var: AIDER_STREAM]'
complete -c aider -l no-stream -f -d 'Disable streaming responses [env var: AIDER_STREAM=False]'
complete -c aider -l user-input-color -r -f -d 'Set color for user input (default: #00cc00) [env var: AIDER_USER_INPUT_COLOR]'
complete -c aider -l tool-output-color -r -f -d 'Set color for tool output [env var: AIDER_TOOL_OUTPUT_COLOR]'
complete -c aider -l tool-error-color -r -f -d 'Set color for tool error messages (default: #FF2222) [env var: AIDER_TOOL_ERROR_COLOR]'
complete -c aider -l tool-warning-color -r -f -d 'Set color for tool warning messages (default: #FFA500) [env var: AIDER_TOOL_WARNING_COLOR]'
complete -c aider -l assistant-output-color -r -f -d 'Set color for assistant output (default: #0088ff) [env var: AIDER_ASSISTANT_OUTPUT_COLOR]'
complete -c aider -l completion-menu-color -r -f -d 'Set color for completion menu text [env var: AIDER_COMPLETION_MENU_COLOR]'
complete -c aider -l completion-menu-bg-color -r -f -d 'Set background color for completion menu [env var: AIDER_COMPLETION_MENU_BG_COLOR]'
complete -c aider -l completion-menu-current-color -r -f -d 'Set color for current item in completion menu [env var: AIDER_COMPLETION_MENU_CURRENT_COLOR]'
complete -c aider -l completion-menu-current-bg-color -r -f -d 'Set background color for current item in completion menu [env var: AIDER_COMPLETION_MENU_CURRENT_BG_COLOR]'
complete -c aider -l code-theme -r -f -a "(string split ' ' default emacs friendly friendly_grayscale github-dark gruvbox-dark gruvbox-light igor inkpot lovelace manni monokai murphy native paraiso-dark paraiso-light pastie perldoc rainbow_dash rrt solarized-dark solarized-light stata stata-dark stata-light tango trac vim vs xcode xcode-dark)" -d 'Set markdown code theme (Pygments style) [env var: AIDER_CODE_THEME]'
complete -c aider -l show-diffs -f -d 'Show diffs when committing changes (default: False) [env var: AIDER_SHOW_DIFFS]'

# --- Git settings ---
complete -c aider -l git -f -d 'Enable looking for a git repo (default: True) [env var: AIDER_GIT]'
complete -c aider -l no-git -f -d 'Disable looking for a git repo [env var: AIDER_GIT=False]'
complete -c aider -l gitignore -f -d 'Enable adding .aider* to .gitignore (default: True) [env var: AIDER_GITIGNORE]'
complete -c aider -l no-gitignore -f -d 'Disable adding .aider* to .gitignore [env var: AIDER_GITIGNORE=False]'
complete -c aider -l aiderignore -r -d 'Specify the aider ignore file [env var: AIDER_AIDERIGNORE]' # File path ok
complete -c aider -l subtree-only -f -d 'Only consider files in the current git subtree [env var: AIDER_SUBTREE_ONLY]'
complete -c aider -l auto-commits -f -d 'Enable auto commit of LLM changes (default: True) [env var: AIDER_AUTO_COMMITS]'
complete -c aider -l no-auto-commits -f -d 'Disable auto commit of LLM changes [env var: AIDER_AUTO_COMMITS=False]'
complete -c aider -l dirty-commits -f -d 'Enable commits when repo is dirty (default: True) [env var: AIDER_DIRTY_COMMITS]'
complete -c aider -l no-dirty-commits -f -d 'Disable commits when repo is dirty [env var: AIDER_DIRTY_COMMITS=False]'
complete -c aider -l attribute-author -f -d 'Attribute changes in git author name (default: True) [env var: AIDER_ATTRIBUTE_AUTHOR]'
complete -c aider -l no-attribute-author -f -d 'Do not attribute changes in git author name [env var: AIDER_ATTRIBUTE_AUTHOR=False]'
complete -c aider -l attribute-committer -f -d 'Attribute commits in git committer name (default: True) [env var: AIDER_ATTRIBUTE_COMMITTER]'
complete -c aider -l no-attribute-committer -f -d 'Do not attribute commits in git committer name [env var: AIDER_ATTRIBUTE_COMMITTER=False]'
complete -c aider -l attribute-commit-message-author -f -d 'Prefix commit messages with "aider:" if aider authored (default: False) [env var: AIDER_ATTRIBUTE_COMMIT_MESSAGE_AUTHOR]'
complete -c aider -l no-attribute-commit-message-author -f -d 'Do not prefix commit messages if aider authored [env var: AIDER_ATTRIBUTE_COMMIT_MESSAGE_AUTHOR=False]'
complete -c aider -l attribute-commit-message-committer -f -d 'Prefix all commit messages with "aider:" (default: False) [env var: AIDER_ATTRIBUTE_COMMIT_MESSAGE_COMMITTER]'
complete -c aider -l no-attribute-commit-message-committer -f -d 'Do not prefix all commit messages with "aider:" [env var: AIDER_ATTRIBUTE_COMMIT_MESSAGE_COMMITTER=False]'
complete -c aider -l git-commit-verify -f -d 'Enable git pre-commit hooks (default: False) [env var: AIDER_GIT_COMMIT_VERIFY]'
complete -c aider -l no-git-commit-verify -f -d 'Disable git pre-commit hooks (--no-verify) [env var: AIDER_GIT_COMMIT_VERIFY=False]'
complete -c aider -l commit -f -d 'Commit pending changes and exit [env var: AIDER_COMMIT]'
complete -c aider -l commit-prompt -r -f -d 'Custom prompt for generating commit messages [env var: AIDER_COMMIT_PROMPT]'
complete -c aider -l dry-run -f -d 'Perform dry run without modifying files (default: False) [env var: AIDER_DRY_RUN]'
complete -c aider -l no-dry-run -f -d 'Do not perform dry run [env var: AIDER_DRY_RUN=False]'
complete -c aider -l skip-sanity-check-repo -f -d 'Skip sanity check for git repository (default: False) [env var: AIDER_SKIP_SANITY_CHECK_REPO]'
complete -c aider -l watch-files -f -d 'Enable watching files for ai coding comments (default: False) [env var: AIDER_WATCH_FILES]'
complete -c aider -l no-watch-files -f -d 'Disable watching files [env var: AIDER_WATCH_FILES=False]'

# --- Fixing and committing ---
complete -c aider -l lint -f -d 'Lint and fix provided/dirty files [env var: AIDER_LINT]'
complete -c aider -l lint-cmd -r -f -d 'Specify lint commands (e.g., "python: flake8") [env var: AIDER_LINT_CMD]'
complete -c aider -l auto-lint -f -d 'Enable automatic linting after changes (default: True) [env var: AIDER_AUTO_LINT]'
complete -c aider -l no-auto-lint -f -d 'Disable automatic linting [env var: AIDER_AUTO_LINT=False]'
complete -c aider -l test-cmd -r -f -d 'Specify command to run tests [env var: AIDER_TEST_CMD]'
complete -c aider -l auto-test -f -d 'Enable automatic testing after changes (default: False) [env var: AIDER_AUTO_TEST]'
complete -c aider -l no-auto-test -f -d 'Disable automatic testing [env var: AIDER_AUTO_TEST=False]'
complete -c aider -l test -f -d 'Run tests, fix problems, then exit [env var: AIDER_TEST]'

# --- Analytics ---
complete -c aider -l analytics -f -d 'Enable analytics for current session (default: random) [env var: AIDER_ANALYTICS]'
complete -c aider -l no-analytics -f -d 'Disable analytics for current session [env var: AIDER_ANALYTICS=False]'
complete -c aider -l analytics-log -r -d 'Specify file to log analytics events [env var: AIDER_ANALYTICS_LOG]' # File path ok
complete -c aider -l analytics-disable -f -d 'Permanently disable analytics [env var: AIDER_ANALYTICS_DISABLE]'

# --- Upgrading ---
complete -c aider -l just-check-update -f -d 'Check for updates and exit with status code [env var: AIDER_JUST_CHECK_UPDATE]'
complete -c aider -l check-update -f -d 'Check for new aider versions on launch [env var: AIDER_CHECK_UPDATE]'
complete -c aider -l no-check-update -f -d 'Do not check for new aider versions on launch [env var: AIDER_CHECK_UPDATE=False]'
complete -c aider -l show-release-notes -f -d 'Show release notes on first run of new version (default: ask) [env var: AIDER_SHOW_RELEASE_NOTES]'
complete -c aider -l no-show-release-notes -f -d 'Do not show release notes on first run of new version [env var: AIDER_SHOW_RELEASE_NOTES=False]'
complete -c aider -l install-main-branch -f -d 'Install latest version from main branch [env var: AIDER_INSTALL_MAIN_BRANCH]'
complete -c aider -l upgrade -f -d 'Upgrade aider to latest version from PyPI [env var: AIDER_UPGRADE]'
complete -c aider -l update -f -d 'Alias for --upgrade [env var: AIDER_UPGRADE]'
complete -c aider -l version -f -d 'Show the version number and exit'

# --- Modes ---
complete -c aider -s m -l message -r -f -d 'Specify single message, process reply, then exit [env var: AIDER_MESSAGE]'
complete -c aider -l msg -r -f -d 'Alias for --message [env var: AIDER_MESSAGE]'
complete -c aider -s f -l message-file -r -d 'Specify file containing message, process reply, then exit [env var: AIDER_MESSAGE_FILE]' # File path ok
complete -c aider -l gui -f -d 'Run aider in your browser (default: False) [env var: AIDER_GUI]'
complete -c aider -l no-gui -f -d 'Do not run aider in browser [env var: AIDER_GUI=False]'
complete -c aider -l browser -f -d 'Alias for --gui [env var: AIDER_GUI]'
complete -c aider -l no-browser -f -d 'Alias for --no-gui [env var: AIDER_GUI=False]'
complete -c aider -l copy-paste -f -d 'Enable auto copy/paste between aider and web UI (default: False) [env var: AIDER_COPY_PASTE]'
complete -c aider -l no-copy-paste -f -d 'Disable auto copy/paste [env var: AIDER_COPY_PASTE=False]'
complete -c aider -l apply -r -d 'Apply changes from file instead of running chat (debug) [env var: AIDER_APPLY]' # File path ok
complete -c aider -l apply-clipboard-edits -f -d 'Apply clipboard contents as edits (debug) [env var: AIDER_APPLY_CLIPBOARD_EDITS]'
complete -c aider -l exit -f -d 'Do startup activities then exit (debug) [env var: AIDER_EXIT]'
complete -c aider -l show-repo-map -f -d 'Print repo map and exit (debug) [env var: AIDER_SHOW_REPO_MAP]'
complete -c aider -l show-prompts -f -d 'Print system prompts and exit (debug) [env var: AIDER_SHOW_PROMPTS]'

# --- Voice settings ---
complete -c aider -l voice-format -r -f -a "(string split ' ' wav webm mp3)" -d 'Audio format for voice recording (default: wav) [env var: AIDER_VOICE_FORMAT]'
complete -c aider -l voice-language -r -f -d 'Specify language for voice (ISO 639-1 code, default: auto) [env var: AIDER_VOICE_LANGUAGE]' # No dynamic completion
complete -c aider -l voice-input-device -r -f -d 'Specify input device name for voice recording [env var: AIDER_VOICE_INPUT_DEVICE]' # No dynamic completion (system specific)

# --- Other settings ---
complete -c aider -l file -r -d 'Specify a file to edit (multiple uses allowed) [env var: AIDER_FILE]' # File path ok
complete -c aider -l read -r -d 'Specify a read-only file (multiple uses allowed) [env var: AIDER_READ]' # File path ok
complete -c aider -l vim -f -d 'Use VI editing mode in terminal (default: False) [env var: AIDER_VIM]'
complete -c aider -l chat-language -r -f -d 'Specify language for chat (default: system settings) [env var: AIDER_CHAT_LANGUAGE]' # No dynamic completion
complete -c aider -l yes-always -f -d 'Always say yes to confirmations [env var: AIDER_YES_ALWAYS]'
complete -c aider -s v -l verbose -f -d 'Enable verbose output [env var: AIDER_VERBOSE]'
complete -c aider -l load -r -d 'Load and execute /commands from file on launch [env var: AIDER_LOAD]' # File path ok
complete -c aider -l encoding -r -f -d 'Specify encoding for input/output (default: utf-8) [env var: AIDER_ENCODING]' # No dynamic completion
complete -c aider -l line-endings -r -f -a "(string split ' ' platform lf crlf)" -d 'Line endings for writing files (default: platform) [env var: AIDER_LINE_ENDINGS]'
complete -c aider -s c -l config -r -d 'Specify the config file [env var: AIDER_CONFIG_FILE]' # File path ok
complete -c aider -l env-file -r -d 'Specify .env file to load [env var: AIDER_ENV_FILE]' # File path ok
complete -c aider -l suggest-shell-commands -f -d 'Enable suggesting shell commands (default: True) [env var: AIDER_SUGGEST_SHELL_COMMANDS]'
complete -c aider -l no-suggest-shell-commands -f -d 'Disable suggesting shell commands [env var: AIDER_SUGGEST_SHELL_COMMANDS=False]'
complete -c aider -l fancy-input -f -d 'Enable fancy input (history/completion) (default: True) [env var: AIDER_FANCY_INPUT]'
complete -c aider -l no-fancy-input -f -d 'Disable fancy input [env var: AIDER_FANCY_INPUT=False]'
complete -c aider -l multiline -f -d 'Enable multi-line input (Meta-Enter to submit) (default: False) [env var: AIDER_MULTILINE]'
complete -c aider -l no-multiline -f -d 'Disable multi-line input [env var: AIDER_MULTILINE=False]'
complete -c aider -l notifications -f -d 'Enable terminal bell notifications (default: False) [env var: AIDER_NOTIFICATIONS]'
complete -c aider -l no-notifications -f -d 'Disable terminal bell notifications [env var: AIDER_NOTIFICATIONS=False]'
complete -c aider -l notifications-command -r -f -d 'Command for notifications instead of bell [env var: AIDER_NOTIFICATIONS_COMMAND]'
complete -c aider -l detect-urls -f -d 'Enable detection/offering to add URLs (default: True) [env var: AIDER_DETECT_URLS]'
complete -c aider -l no-detect-urls -f -d 'Disable URL detection [env var: AIDER_DETECT_URLS=False]'
complete -c aider -l editor -r -f -a "(__fish_aider_complete_editors_with_flags)" -d 'Specify editor command (wait flags added for GUI editors) [env var: AIDER_EDITOR]'

# --- Deprecated model settings ---
complete -c aider -l opus -f -d '(deprecated) Use claude-3-opus-20240229 model [env var: AIDER_OPUS]'
complete -c aider -l sonnet -f -d '(deprecated) Use claude-3-7-sonnet-20250219 model [env var: AIDER_SONNET]'
complete -c aider -l haiku -f -d '(deprecated) Use claude-3-5-haiku-20241022 model [env var: AIDER_HAIKU]'
complete -c aider -s 4 -l 4 -f -d '(deprecated) Use gpt-4-0613 model [env var: AIDER_4]'
complete -c aider -l 4o -f -d '(deprecated) Use gpt-4o model [env var: AIDER_4O]'
complete -c aider -l mini -f -d '(deprecated) Use gpt-4o-mini model [env var: AIDER_MINI]'
complete -c aider -l 4-turbo -f -d '(deprecated) Use gpt-4-1106-preview model [env var: AIDER_4_TURBO]'
complete -c aider -s 3 -l 3 -f -d '(deprecated) Use gpt-3.5-turbo model [env var: AIDER_35TURBO]'
complete -c aider -l 35turbo -f -d '(deprecated) Use gpt-3.5-turbo model [env var: AIDER_35TURBO]'
complete -c aider -l 35-turbo -f -d '(deprecated) Use gpt-3.5-turbo model [env var: AIDER_35TURBO]'
complete -c aider -l deepseek -f -d '(deprecated) Use deepseek/deepseek-chat model [env var: AIDER_DEEPSEEK]'
complete -c aider -l o1-mini -f -d '(deprecated) Use o1-mini model [env var: AIDER_O1_MINI]'
complete -c aider -l o1-preview -f -d '(deprecated) Use o1-preview model [env var: AIDER_O1_PREVIEW]'
