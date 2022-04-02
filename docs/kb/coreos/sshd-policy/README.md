# sshd Policy

This policy is an application of the recommendations given by ssh-audit[^1].

## Usage

Insert the following into your Butane configuration.

```yaml
variant: fcos
version: 1.4.0
ignition:
  config:
    merge:
    - source: https://docs.doubleu.codes/kb/coreos/sshd-policy/sshd-policy.ign.gz
      compression: gzip
      verification:
        hash: sha512-fe9d38ffb06fcaa83ed7778612d3fc12415a9e54c577c908713620cabc58438f9a741eceac72803c7b3d480650548d3f7e539b5365d050f4b3735b215336dd96
```

Ensure the `sha512` sum reflects the one below, which is loaded directly from
the sum file.

```txt
--8<-- "docs/kb/coreos/sshd-policy/sshd-policy.ign.sha512sum"
```

## Policy Butane Format

```yaml
--8<-- "docs/kb/coreos/sshd-policy/sshd-policy.bu"
```

[^1]: [https://github.com/jtesta/ssh-audit](https://github.com/jtesta/ssh-audit){target=_blank rel="nofollow noopener noreferrer"}
