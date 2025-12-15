# Presentations

This folder contains markdown-based presentations that can be viewed and converted using [MARP CLI](https://github.com/marp-team/marp-cli).

## Installation

Install MARP CLI using npm:

```bash
npm install --save-dev @marp-team/marp-cli
```

## Usage

### Preview Presentations

To preview presentations in your browser with live reload:

```bash
npx marp -s presentations/decks --open
```

This will start a server and watch all presentations in the `decks/` directory. From here you can view the presentation in your browser, convert to PDF or convert to PPT.

### Convert to HTML using CLI

Convert a markdown presentation to HTML:

```bash
npx marp <filename>.md -o <output>.html
```

### Convert to PDF using CLI

Convert a markdown presentation to PDF:

```bash
npx marp <filename>.md --pdf -o <output>.pdf
```

### Convert to PowerPoint using CLI

Convert a markdown presentation to PowerPoint:

```bash
npx marp <filename>.md --pptx -o <output>.pptx
```

## Additional Resources

- [MARP Documentation](https://marpit.marp.app/)
- [MARP CLI GitHub](https://github.com/marp-team/marp-cli)
- [MARP VS Code Extension](https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode)
- [MARP Themes](https://github.com/marp-team/marp-core/tree/main/themes)
