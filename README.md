# Avanço Missionário

A production desktop app built for the Avanço Missionário event, organized by the church [ACEV](https://acevbrasil.org.br/) Ação Evangélica, from [Patos](https://en.wikipedia.org/wiki/Patos), Paraíba. It helps the staff team plan and distribute daily tasks during a fast-paced, multi-day mission trip. This is a real-world Flutter desktop project shipped to users on Windows.

## Demo

![](./docs/demo.gif)

## Why it matters

The event runs on people, not paperwork. The app makes task assignment clear and fair, so volunteers can focus on serving rather than coordinating. It is a small tool with a big impact on daily operations.

## What it does

- Centralizes staff, tasks, and daily assignments
- Balances team workload with quick drag-and-drop assignment
- Generates daily PDFs for printed distribution
- Ships as a Windows installer for non-technical staff

## Design story

The UX started as a hand-drawn low-fidelity sketch, then moved to high-fidelity mockups in [Google Stitch](https://stitch.withgoogle.com/). The UI favors clarity and speed for a busy staff environment.

## Tech stack

- [Flutter](https://flutter.dev/)
- Local SQLite database, using [sqflite](https://pub.dev/packages/sqflite) package
- PDF generation for reports, using [pdf](https://pub.dev/packages/pdf) package

## Distribution and releases

The app is packaged with [Inno Setup](https://jrsoftware.org/isinfo.php). Releases are automated through GitHub Actions and triggered by tags, producing an installer for Windows.

## Roadmap

- Form capture: read a photo/camera image, extract the content, and prefill the fields

## Code status

This project was largely vibecoded with [Codex](https://openai.com/codex/) and minimal quality supervision. It is functional, but the codebase has uneven structure and test coverage. Refactoring and tests are welcome.
