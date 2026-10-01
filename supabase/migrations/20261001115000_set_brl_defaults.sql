-- A planilha de referência trabalha em R$. Mantém novas medições em BRL
-- sem alterar regras de tarifa nem inventar valores comerciais.
alter table medicao.rate_rules alter column currency set default 'BRL';
alter table medicao.measurements alter column currency set default 'BRL';
update medicao.measurements set currency = 'BRL' where currency = 'USD';
