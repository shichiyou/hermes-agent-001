# Wiki path (LLM Wiki skill)
export WIKI_PATH="/workspaces/hermes-agent-template/wiki"

# Wiki symlink (for convenience)
if [ -L "$HOME/wiki" ] && [ ! -e "$HOME/wiki" ]; then
    rm "$HOME/wiki"
fi

if [ ! -e "$HOME/wiki" ] && [ ! -L "$HOME/wiki" ]; then
    ln -s /workspaces/hermes-agent-template/wiki "$HOME/wiki"
fi
