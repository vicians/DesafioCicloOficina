import { Request, Response } from 'express';
import { OficinaModel } from '../models/oficinaModel';

export class OficinaController {
  static async index(req: Request, res: Response) {
    const oficinas = await OficinaModel.findAll();
    return res.json(oficinas);
  }

  static async show(req: Request, res: Response) {
    const { id } = req.params;
    const oficina = await OficinaModel.findById(id);
    if (!oficina) return res.status(404).json({ error: 'Oficina não encontrada' });
    return res.json(oficina);
  }

  static async update(req: Request, res: Response) {
    const { id } = req.params;
    const { nome, quantidade_boxes } = req.body;

    const oficina = await OficinaModel.update(id, { nome, quantidade_boxes });
    if (!oficina) return res.status(404).json({ error: 'Oficina não encontrada' });
    return res.json(oficina);
  }
}
