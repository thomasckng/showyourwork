from showyourwork import paths, exceptions, overleaf
from showyourwork.patches import patch_snakemake_wait_for_files, patch_snakemake_logging
from showyourwork.config import parse_config, get_run_type
from showyourwork.logging import get_logger
from showyourwork.userrules import process_user_rules
import snakemake
import sys
import os
import jinja2


# Require Snakemake >= this version
snakemake.utils.min_version("6.15.5")


# Working directory is the top level of the user repo
workdir: paths.user().repo.as_posix()


# What kind of run is this? (clean, build, etc.)
run_type = get_run_type()


# The configfile is autogenerated by the `prep.smk` workflow
if (paths.user().temp / "config.json").exists():


    # Load the autogenerated config
    configfile: (paths.user().temp / "config.json").as_posix()


    # Workflow report template
    report: "report/workflow.rst"


    # Set up custom logging for Snakemake
    patch_snakemake_logging()


    # Parse the config file
    parse_config()


    # Hack to make the pdf generation the default rule
    rule syw__main:
        input:
            config["ms_pdf"]


    # Wrap the tarball generation rule to ensure tempfiles are properly
    # deleted; this is the rule we actually call from the Makefile
    rule syw__arxiv_entrypoint:
        input:
            "arxiv.tar.gz"


    # Include all other rules
    include: "checkpoints/dag.smk"
    include: "rules/arxiv.smk"
    include: "rules/compile.smk"
    include: "rules/zenodo.smk"
    include: "rules/figure.smk"


    # Resolve ambiguities in rule order
    ruleorder: syw__compile > syw__arxiv


    # Include custom rules defined by the user
    include: (paths.user().repo / "Snakefile").as_posix()
    process_user_rules()


    # Hack to display a custom message when a figure output is missing
    patch_snakemake_wait_for_files()


else:


    if run_type != "clean":
        raise exceptions.MissingConfigFile()


onsuccess:


    # Overleaf sync: push changes
    if run_type == "build":
        overleaf.push_files(config["overleaf"]["push"], config["overleaf"]["id"])


    # We're done
    get_logger().info("Done!")
