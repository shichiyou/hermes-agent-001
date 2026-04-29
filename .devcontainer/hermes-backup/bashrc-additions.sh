# Wiki path (LLM Wiki skill)
export WIKI_PATH="/workspaces/hermes-agent-001/wiki"

# Wiki symlink (for convenience)
if [ -L "$HOME/wiki" ] && [ ! -e "$HOME/wiki" ]; then
    rm "$HOME/wiki"
fi

if [ ! -e "$HOME/wiki" ] && [ ! -L "$HOME/wiki" ]; then
    ln -s /workspaces/hermes-agent-001/wiki "$HOME/wiki"
fi
