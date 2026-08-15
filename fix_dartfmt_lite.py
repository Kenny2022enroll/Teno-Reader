#!/usr/bin/env python3
"""Undo overly aggressive trailing commas added by the previous pass.

Fixes these patterns:
  return foo;  ,    ->    return foo;
  break;       ,    ->    break;
  continue;    ,    ->    continue;
  } else {          (if the line is "} else {")  leave alone
  } catch (e) {,    ->    } catch (e) {
  } catch (_) {},   ->    } catch (_) {}
  statement();,     ->    statement();     (only when clearly a standalone statement,
                                             i.e. the line starts with indent + identifier
                                             or indent + keyword that isn't a map entry)

Actually simpler heuristic: any line ending with ";," is a statement, not an entry.
Remove the trailing comma from those.

Also lines ending with "} else,{" or "} finally,{" etc. are bad.
"""
import sys
import re


def fix(text):
    out_lines = []
    for line in text.split('\n'):
        # Statement ending with ";" followed by erroneous trailing comma
        if line.rstrip().endswith(';,'):
            line = line.rstrip()[:-1]
        # "} catch (e) {," or "} catch (_) {,"
        line = re.sub(r'\} (catch|else|finally|for|while)(.*)\{,$',
                      r'} \1\2{', line)
        # } catch (_) {},  <- standalone statement
        if re.search(r'\} catch \([^)]*\) \{\s*,$', line.rstrip()):
            line = line.rstrip()[:-1]
        # if/for/while blocks: ") {,"  → ") {"  when at statement level
        line = re.sub(r'([\w])\) \{,$', r'\1) {', line)
        # Lines ending with ",\s*" where the comma is clearly wrong:
        # e.g. "}, else {"
        line = re.sub(r'\}, else \{', r'} else {', line)
        out_lines.append(line)
    return '\n'.join(out_lines)


if __name__ == '__main__':
    for p in sys.argv[1:]:
        with open(p, 'r', encoding='utf-8') as f:
            src = f.read()
        new = fix(src)
        with open(p, 'w', encoding='utf-8') as f:
            f.write(new)
        diff = sum(1 for a, b in zip(src.split('\n'), new.split('\n')) if a != b)
        print('{}: {} lines fixed'.format(p, diff))
